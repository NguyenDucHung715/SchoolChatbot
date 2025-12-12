from pathlib import Path
from collections import Counter
import json


LOG_FILE = Path("logs/chat_history.jsonl")


def load_logs():
    """Đọc toàn bộ log từ file JSONL thành list[dict]."""
    if not LOG_FILE.exists():
        print(f"⚠ Không tìm thấy file log: {LOG_FILE}")
        return []

    entries = []
    with LOG_FILE.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                entries.append(obj)
            except json.JSONDecodeError:
                # Nếu có dòng bị lỗi format thì bỏ qua, không cho script bị crash
                print("⚠ Bỏ qua 1 dòng log lỗi:", line[:80], "...")
    return entries


def main():
    logs = load_logs()
    if not logs:
        print("Chưa có dữ liệu log để thống kê.")
        return

    total = len(logs)
    print("=== THỐNG KÊ LỊCH SỬ CHAT ===")
    print(f"Tổng số lượt hỏi–đáp: {total}")
    print()

    # 1. Đếm theo nguồn trả lời (FAQ / AI / System)
    by_source = Counter(entry.get("source", "unknown") for entry in logs)
    print("1) Thống kê theo nguồn trả lời (source):")
    for src, count in by_source.items():
        percent = count * 100 / total
        print(f"   - {src:7s}: {count:3d} lượt ({percent:5.1f}%)")
    print()

    # 2. Đếm theo topic (chỉ những câu trả lời từ FAQ có topic)
    by_topic = Counter((entry.get("topic") or "không có (AI/System)") for entry in logs)
    print("2) Thống kê theo chủ đề (topic):")
    for topic, count in by_topic.items():
        percent = count * 100 / total
        print(f"   - {topic:25s}: {count:3d} lượt ({percent:5.1f}%)")
    print()

    # 3. In 5 dòng log gần nhất cho dễ xem
    print("3) 5 lượt hỏi–đáp gần nhất:")
    for entry in logs[-5:]:
        ts = entry.get("timestamp", "?")
        user_text = entry.get("user_text", "")[:60]
        reply_src = entry.get("source", "unknown")
        print(f"   [{ts}] ({reply_src}) {user_text}")
    print()
    print("=> Có thể copy các số liệu trên bỏ vào phần 'Kết quả thực nghiệm' của báo cáo.")


if __name__ == "__main__":
    main()
