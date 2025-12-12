import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../chat_message.dart'; // model ChatMessage nằm ở lib/chat_message.dart

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  // Nếu chạy Android emulator: đổi 127.0.0.1 -> 10.0.2.2
  final String _apiUrl = 'http://127.0.0.1:8000/chat';

  // 💡 Các câu hỏi gợi ý cho sinh viên
  final List<String> _quickQuestions = [
    'Thông tin tuyển sinh ngành Công nghệ thông tin.',
    'Điều kiện xét tuyển của trường là gì?',
    'Học phí 1 năm khoảng bao nhiêu?',
    'Có những loại học bổng nào?',
    'Điều kiện nhận học bổng là gì?',
    'Thủ tục nhập học cần những giấy tờ gì?',
    'Quy định về bảo lưu, tạm dừng học như thế nào?',
    'Thời gian học, lịch học trong tuần ra sao?',
  ];

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 1. Thêm tin nhắn người dùng
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isSending = true;
    });

    try {
      final uri = Uri.parse(_apiUrl);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final reply =
            data['reply'] as String? ?? 'Không nhận được câu trả lời.';
        final source = data['source'] as String?;
        final faqId = data['faq_id'];
        final topic = data['topic'] as String?;

        _messages.add(
          ChatMessage(
            text: reply,
            isUser: false,
            source: source,
            faqId: faqId is int ? faqId : null,
            topic: topic,
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            text: 'Có lỗi khi kết nối server (mã ${response.statusCode}).',
            isUser: false,
            source: 'system',
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _messages.add(
        ChatMessage(
          text:
              'Không kết nối được tới server. Vui lòng kiểm tra lại.\nLỗi: $e',
          isUser: false,
          source: 'system',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Bubble tin nhắn
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    // màu nền theo nguồn
    final Color bgColor;
    if (isUser) {
      bgColor = Colors.blueAccent;
    } else {
      if (msg.source == 'faq') {
        bgColor = Colors.green.shade100;
      } else if (msg.source == 'ai') {
        bgColor = Colors.orange.shade100;
      } else {
        // system hoặc null
        bgColor = Colors.grey.shade200;
      }
    }

    final align =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.circular(12);

    // label nhỏ bên dưới
    String? sourceLabel;
    if (!isUser) {
      if (msg.source == 'faq') {
        sourceLabel = '💡 Trả lời từ FAQ (${msg.topic ?? "FAQ"})';
      } else if (msg.source == 'ai') {
        sourceLabel = '🤖 Trả lời từ AI (tham khảo)';
      } else if (msg.source == 'system') {
        sourceLabel = '⚙ Thông báo hệ thống';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: radius,
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (sourceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                sourceLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Hàng gợi ý câu hỏi nhanh
  Widget _buildQuickSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickQuestions.map((q) {
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: ActionChip(
                label: Text(
                  q,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _isSending
                    ? null
                    : () {
                        _controller.text = q;
                        _sendMessage();
                      },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý ảo tuyển sinh'),
      ),
      body: Column(
        children: [
          // ⭐ Gợi ý câu hỏi nhanh
          _buildQuickSuggestions(),

          // danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_isSending)
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Đang xử lý câu hỏi của bạn...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // ô nhập + nút gửi
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Nhập câu hỏi của bạn...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
