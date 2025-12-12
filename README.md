# SchoolChatbot – Trợ lý ảo tuyển sinh / hỗ trợ sinh viên

Dự án gồm:
- **Backend**: FastAPI (Python) + FAQ (`faqs.json`) + AI fallback (Gemini → OpenAI)
- **Frontend**: Flutter (giao diện chat) chạy được Web / Android (và có thể mở rộng iOS)
- **Log lịch sử chat**: lưu vào `server/logs/chat_history.jsonl` + script thống kê `server/stats.py`

---

## 1) Cấu trúc thư mục

```text
SchoolChatbot/
├─ client/                 # Flutter app
└─ server/                 # FastAPI backend
