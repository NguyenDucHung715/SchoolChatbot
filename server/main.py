from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI()

# Bật CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class MessageRequest(BaseModel):
    text: str

@app.post("/chat")
async def chat_endpoint(request: MessageRequest):
    user_text = request.text
    print(f"Nhận được tin nhắn: {user_text}")
    bot_reply = f"Server đã nhận: '{user_text}'. Chào bạn!"
    return {"reply": bot_reply}

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
