import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Danh sách tin nhắn (Giả lập ban đầu)
  final List<Map<String, dynamic>> _messages = [
    {"text": "Xin chào! Mình là AI hỗ trợ học tập. Bạn cần giúp gì?", "isUser": false}
  ];
  
  final TextEditingController _controller = TextEditingController();

  // Hàm gửi tin nhắn
  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    // 1. Hiện tin nhắn của bạn lên màn hình
    setState(() {
      _messages.add({"text": _controller.text, "isUser": true});
    });

    String userQuestion = _controller.text;
    _controller.clear();

    // 2. Giả lập Bot trả lời (Sau này sẽ nối với Python ở đây)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add({
          "text": "Mình đã nhận câu hỏi: '$userQuestion'. \n(Tính năng AI đang được xây dựng...)",
          "isUser": false
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot Trường Học"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Phần 1: Danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    child: Text(msg['text'], style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          
          // Phần 2: Ô nhập liệu
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Nhập câu hỏi...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blueAccent,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}