from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from google import genai
from openai import OpenAI
from datetime import datetime
import uvicorn
import os
import time
import unicodedata
import json
import re
from pathlib import Path


app = FastAPI()

# Bật CORS để Flutter Web gọi được API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Sau này có thể siết lại theo domain cụ thể
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MessageRequest(BaseModel):
    text: str

# ================== CẤU HÌNH LOG LỊCH SỬ CHAT ==================

LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)  # Tự tạo thư mục logs nếu chưa có

LOG_FILE = LOG_DIR / "chat_history.jsonl"  # Mỗi dòng là 1 JSON object


def log_chat(
    user_text: str,
    reply: str,
    source: str | None = None,
    faq_id: int | None = None,
    topic: str | None = None,
) -> None:
    """
    Ghi 1 bản ghi hỏi–đáp vào file logs/chat_history.jsonl
    (mỗi dòng là 1 JSON, dễ phân tích sau này).
    """
    try:
        entry = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "user_text": user_text,
            "reply": reply,
            "source": source,  # 'faq' | 'ai' | 'system'
            "faq_id": faq_id,
            "topic": topic,
        }

        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    except Exception as e:
        # Không để việc log làm crash server
        print("⚠ Không ghi được log:", e)



# ====== Load .env & cấu hình client AI ======
load_dotenv()

# ---- Gemini ----
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
gemini_client = None

if GEMINI_API_KEY:
    try:
        gemini_client = genai.Client(api_key=GEMINI_API_KEY)
        print("✅ Gemini client khởi tạo thành công.")
    except Exception as e:
        print("❌ Lỗi khi khởi tạo Gemini client:", e)
else:
    print("⚠️ Chưa thấy GEMINI_API_KEY trong môi trường. Fallback AI sẽ không hoạt động.")

# ---- ChatGPT (OpenAI) ----
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
openai_client = None

if OPENAI_API_KEY:
    try:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)
        print("✅ OpenAI client khởi tạo thành công.")
    except Exception as e:
        print("❌ Lỗi khi khởi tạo OpenAI client:", e)
else:
    print("⚠️ Chưa thấy OPENAI_API_KEY trong môi trường.")


# ================== CƠ SỞ TRI THỨC FAQ (15 CÂU HỎI – ĐÁP) ==================
# TODO: Thay nội dung answer/keywords cho đúng với TRƯỜNG CỦA BẠN

# ================== CƠ SỞ TRI THỨC FAQ (LOAD TỪ faqs.json) ==================

FAQS: list[dict] = []

def load_faqs():
    """
    Đọc danh sách FAQ từ file faqs.json đặt cùng thư mục với main.py
    """
    global FAQS
    faq_path = Path(__file__).parent / "faqs.json"
    try:
        with faq_path.open("r", encoding="utf-8") as f:
            FAQS = json.load(f)
        print(f"✅ Đã load {len(FAQS)} FAQ từ {faq_path.name}")
    except FileNotFoundError:
        print("❌ Không tìm thấy file faqs.json. Vui lòng tạo file này trong thư mục server.")
        FAQS = []
    except Exception as e:
        print("❌ Lỗi khi đọc faqs.json:", e)
        FAQS = []

# Gọi load_faqs khi khởi động server
load_faqs()



SYSTEM_PROMPT = """
Bạn là trợ lý ảo hỗ trợ sinh viên cho một trường đại học ở Việt Nam.
Nhiệm vụ:
- Giải đáp về tuyển sinh, quy chế, học phí, học bổng, thủ tục sinh viên.
- Trả lời ngắn gọn, rõ ràng, tiếng Việt.
- Khi không chắc số liệu/mốc thời gian chính xác, hãy nói không chắc
  và khuyên sinh viên xem trên website hoặc liên hệ phòng đào tạo.
"""

def normalize_vi(text: str) -> str:
    """
    Chuẩn hóa chuỗi tiếng Việt:
    - chuyển về chữ thường
    - bỏ khoảng trắng dư thừa
    - đổi 'đ' -> 'd'
    - bỏ toàn bộ dấu (sắc, huyền, hỏi, ngã, nặng, â, ê, ô, ă, ơ, ư...)
    """
    text = text.lower().strip()
    text = text.replace("đ", "d")
    # tách dấu
    text = unicodedata.normalize("NFD", text)
    # bỏ ký tự dấu
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    return text


def ask_gemini(user_text: str) -> str | None:
    """
    Gọi Gemini.
    - Thử tối đa 3 lần nếu gặp lỗi 503/UNAVAILABLE (model quá tải).
    - Trả về chuỗi nếu OK, None nếu hết lượt mà vẫn lỗi.
    """
    if gemini_client is None:
        return None

    max_retries = 3
    base_delay = 2  # giây

    for attempt in range(max_retries):
        try:
            response = gemini_client.models.generate_content(
                model="gemini-1.5-flash",
                contents=[
                    SYSTEM_PROMPT,
                    f"Người dùng hỏi: {user_text}",
                ],
            )

            reply = getattr(response, "text", None)
            if reply:
                return reply
            # gọi được nhưng rỗng -> coi như fail
            return None

        except Exception as e:
            err_str = str(e)
            print(f"Lỗi khi gọi Gemini (lần {attempt + 1}):", err_str)

            # Nếu là lỗi quá tải 503/UNAVAILABLE và còn lượt thử
            if ("503" in err_str or "UNAVAILABLE" in err_str) and attempt < max_retries - 1:
                delay = base_delay * (attempt + 1)  # 2s, 4s, ...
                print(f"Đợi {delay} giây rồi thử lại Gemini...")
                time.sleep(delay)
                continue

            # Lỗi khác hoặc đã hết lượt retry
            return None

    return None


def ask_chatgpt(user_text: str) -> str | None:
    """
    Gọi OpenAI ChatGPT (gpt-4o-mini) làm fallback.
    Trả về chuỗi nếu OK, None nếu lỗi hoặc chưa cấu hình.
    """
    if openai_client is None:
        return None

    try:
        completion = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_text},
            ],
            max_tokens=512,
        )
        reply = completion.choices[0].message.content
        return reply
    except Exception as e:
        print("Lỗi khi gọi ChatGPT:", e)
        return None


def ask_ai_with_fallback(user_text: str) -> str:
    """
    Thử Gemini trước, nếu lỗi/None thì thử ChatGPT.
    Cuối cùng nếu cả hai đều fail thì trả về thông báo chung.
    """
    # 1. Thử Gemini
    gemini_reply = ask_gemini(user_text)
    if gemini_reply:
        return gemini_reply

    # 2. Gemini lỗi / quá tải -> thử ChatGPT
    chatgpt_reply = ask_chatgpt(user_text)
    if chatgpt_reply:
        return chatgpt_reply

    # 3. Cả hai đều fail
    return (
        "Hiện tại hệ thống AI đang gặp sự cố nên mình chưa trả lời chi tiết được. "
        "Bạn vui lòng thử lại sau hoặc liên hệ phòng đào tạo để được hỗ trợ."
    )

# ===============================================================
STOP_KW = {"thong", "tin", "truong", "dai", "hoc", "cao", "dang", "khoa", "nganh"}

def tokenize(norm_text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", norm_text)

# ================== HÀM TÌM CÂU TRẢ LỜI TỪ FAQ ==================

def find_faq_answer(user_text: str) -> dict | None:
    if not user_text:
        return None

    txt_norm = normalize_vi(user_text)
    txt_tokens = set(tokenize(txt_norm))

    # 1) match nguyên câu hỏi (ưu tiên tuyệt đối)
    for faq in FAQS:
        questions_norm = [normalize_vi(q) for q in faq.get("questions", [])]
        if txt_norm in questions_norm:
            return {
                "answer": faq.get("answer", ""),
                "topic": faq.get("topic", ""),
                "id": faq.get("id"),
            }

    # 2) match keyword có chấm điểm (tránh keyword chung chung)
    best = None
    best_score = 0

    for faq in FAQS:
        score = 0
        for kw in faq.get("keywords", []):
            kw_norm = normalize_vi(kw).strip()
            if not kw_norm:
                continue

            kw_tokens = tokenize(kw_norm)
            if not kw_tokens:
                continue

            # bỏ keyword quá chung chung
            if all(t in STOP_KW for t in kw_tokens):
                continue

            # keyword 1 từ -> match theo token
            if len(kw_tokens) == 1:
                if kw_tokens[0] in txt_tokens:
                    score += 1
            else:
                # keyword nhiều từ -> match theo cụm có biên từ
                phrase = " ".join(kw_tokens)
                pattern = r"\b" + re.escape(phrase) + r"\b"
                if re.search(pattern, txt_norm):
                    score += 2  # cụm từ cho điểm cao hơn

        if score > best_score:
            best_score = score
            best = faq

    # Ngưỡng: phải đủ “chắc” mới coi là có trong FAQ
    if best and best_score >= 2:
        return {
            "answer": best.get("answer", ""),
            "topic": best.get("topic", ""),
            "id": best.get("id"),
        }

    return None





# ================== API CHÍNH /chat ==================

@app.post("/chat")
async def chat_endpoint(request: MessageRequest):
    user_text = request.text.strip()
    print(f"Nhận được tin nhắn: {user_text}")

    if not user_text:
        bot_reply = "Bạn hãy nhập câu hỏi nhé, mình chưa thấy nội dung gì. 😊"
        # log luôn: câu rỗng + system
        log_chat(
            user_text=user_text,
            reply=bot_reply,
            source="system",
            faq_id=None,
            topic=None,
        )
        return {
            "reply": bot_reply,
            "source": "system",
            "faq_id": None,
            "topic": None,
        }

    # 1. Thử trả lời bằng FAQ trước
    faq_result = find_faq_answer(user_text)
    if faq_result is not None:
        faq_answer = faq_result.get("answer", "")
        faq_id = faq_result.get("id")
        topic = faq_result.get("topic")
        log_chat(
            user_text=user_text,
            reply=faq_answer,
            source="faq",
            faq_id=faq_id,
            topic=topic,
        )
        return {
            "reply": faq_answer,
            "source": "faq",
            "faq_id": faq_id,
            "topic": topic,
        }

    # 2. Không có trong FAQ -> gọi AI với fallback (Gemini -> ChatGPT)
    ai_answer = ask_ai_with_fallback(user_text)
    if ai_answer is not None:
        log_chat(
            user_text=user_text,
            reply=ai_answer,
            source="ai",
            faq_id=None,
            topic=None,
        )
        return {
            "reply": ai_answer,
            "source": "ai",
            "faq_id": None,
            "topic": None,
        }

    # 3. Cả FAQ và AI đều lỗi -> trả về thông báo hệ thống
    fallback_reply = (
        "Hiện tại hệ thống AI đang gặp sự cố nên mình chưa trả lời chi tiết được. "
        "Bạn vui lòng thử lại sau hoặc liên hệ phòng đào tạo để được hỗ trợ."
    )
    log_chat(
        user_text=user_text,
        reply=fallback_reply,
        source="system",
        faq_id=None,
        topic=None,
    )
    return {
        "reply": fallback_reply,
        "source": "system",
        "faq_id": None,
        "topic": None,
    }




if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
