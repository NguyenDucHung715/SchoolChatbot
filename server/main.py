from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI()

# Định nghĩa khuôn mẫu dữ liệu tin nhắn gửi lên
class MessageRequest(BaseModel):
    text: str

@app.post("/chat")
async def chat_endpoint(request: MessageRequest):
    user_text = request.text
    print(f"Nhận được tin nhắn: {user_text}") # In ra terminal để kiểm tra
    
    # Logic trả lời đơn giản (Sau này lắp AI vào đây)
    bot_reply = f"Server đã nhận: '{user_text}'. Chào bạn!"
    
    return {"reply": bot_reply}

if __name__ == "__main__":
    # Reload=True để sửa code xong nó tự cập nhật không cần tắt đi bật lại
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)