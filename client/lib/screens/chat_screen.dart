import 'dart:convert'; // Để xử lý dữ liệu JSON
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Thư viện gọi Server

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // List tin nhắn
  bool _isLoading = false; // Trạng thái chờ server

  // Hàm gọi Server Python
  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    // 1. Lấy nội dung user nhập
    String userText = _controller.text;
    _controller.clear();

    // 2. Hiện tin nhắn User lên màn hình ngay lập tức
    setState(() {
      _messages.add({"text": userText, "isUser": true});
      _isLoading = true; // Bật icon loading
    });

    try {
      // 3. Gửi sang Server Python
      // Lưu ý: Nếu chạy trên Android Emulator thì đổi 127.0.0.1 thành 10.0.2.2
      final url = Uri.parse('http://127.0.0.1:8000/chat'); 
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": userText}),
      );

      // 4. Xử lý kết quả trả về
      if (response.statusCode == 200) {
        // Giải mã cục JSON từ server: {"reply": "..."}
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String botReply = data['reply'];

        setState(() {
          _messages.add({"text": botReply, "isUser": false});
        });
      } else {
        setState(() {
          _messages.add({"text": "Lỗi Server: ${response.statusCode}", "isUser": false});
        });
      }
    } catch (e) {
      // Nếu mất mạng hoặc server chưa bật
      setState(() {
        _messages.add({"text": "Không kết nối được Server!\nLỗi: $e", "isUser": false});
      });
    } finally {
      setState(() {
        _isLoading = false; // Tắt icon loading dù thành công hay thất bại
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot Sinh Viên"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // KHUNG HIỂN THỊ TIN NHẮN
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
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      msg['text'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),

          // ICON LOADING (Khi đang chờ server)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),

          // KHUNG NHẬP LIỆU
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Hỏi gì đi bạn...",
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