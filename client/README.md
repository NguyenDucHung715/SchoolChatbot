# 📚 School Chatbot – Trợ lý ảo tuyển sinh & hỗ trợ sinh viên

Dự án xây dựng một ứng dụng **chatbot hỗ trợ tuyển sinh / sinh viên** gồm:

- 🧠 **Backend**: FastAPI + kho **FAQ** + AI (Gemini + ChatGPT fallback)
- 📱 **Frontend**: Ứng dụng Flutter (web/mobile) giao diện chat thân thiện
- 📝 **Log lịch sử**: Lưu tất cả hỏi–đáp để phục vụ thống kê & báo cáo

---

## 1. Kiến trúc tổng quan

```text
Flutter Client (web/mobile)
        |
        |  HTTP POST /chat  (JSON: { "text": "..." })
        v
FastAPI Backend (Python)
        |
        |-- 1. Chuẩn hoá tiếng Việt (bỏ dấu, lower-case, ... )
        |-- 2. Tìm trong kho FAQ (faqs.json)
        |       └→ Nếu tìm được: trả lời ngay, source = "faq"
        |
        |-- 3. Nếu không có trong FAQ:
        |       └→ Gọi AI:
        |             - Ưu tiên Gemini (google-genai)
        |             - Nếu lỗi/quá tải → fallback sang OpenAI (ChatGPT)
        |       └→ source = "ai"
        |
        └-- 4. Nếu cả FAQ & AI đều lỗi:
                └→ Trả về thông báo hệ thống, source = "system"

Mỗi lượt hỏi–đáp đều được ghi vào: server/logs/chat_history.jsonl
