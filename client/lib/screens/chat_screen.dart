import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart'; // Thư viện font
import 'package:intl/intl.dart'; // Thư viện giờ

// --- MODEL TIN NHẮN (Định nghĩa ngay tại đây để chạy luôn) ---
class ChatMessage {
  final String text;
  final bool isUser;
  final String? source; // 'faq', 'ai', 'system'
  final int? faqId;
  final String? topic;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.source,
    this.faqId,
    this.topic,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}
// -----------------------------------------------------------

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // ⚠️ LƯU Ý: Đổi IP nếu chạy máy thật (VD: 192.168.1.x)
  final String _apiUrl = 'http://127.0.0.1:8000/chat';

  // Câu hỏi gợi ý
  final List<String> _quickQuestions = [
    'Thông tin tuyển sinh ngành CNTT',
    'Học phí 1 năm bao nhiêu?',
    'Điều kiện nhận học bổng?',
    'Thủ tục nhập học cần gì?',
    'Ký túc xá trường ở đâu?',
  ];

  @override
  void initState() {
    super.initState();
    // Thêm tin nhắn chào mừng mặc định
    _messages.add(ChatMessage(
      text: "Xin chào! Mình là Trợ lý ảo Tuyển sinh.\nMình có thể giúp gì cho bạn hôm nay? ✨",
      isUser: false,
      source: 'system',
    ));
  }

  // Hàm cuộn xuống cuối
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text}) async {
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true));
      _controller.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': messageText}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        setState(() {
          _messages.add(ChatMessage(
            text: data['reply'] ?? 'Không có phản hồi.',
            isUser: false,
            source: data['source'],
            faqId: data['faq_id'],
            topic: data['topic'],
          ));
        });
      } else {
        _addSystemMessage('Lỗi kết nối Server (Mã: ${response.statusCode})');
      }
    } catch (e) {
      _addSystemMessage('Không thể kết nối đến Server.\nHãy kiểm tra lại Backend.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false, source: 'system'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB), // Màu nền xám xanh nhạt sang trọng
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // DANH SÁCH TIN NHẮN
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // GỢI Ý NHANH
          _buildQuickSuggestions(),

          // Ô NHẬP LIỆU
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- 1. APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tư Vấn Tuyển Sinh',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Trực tuyến',
                    style: GoogleFonts.inter(color: Colors.green, fontSize: 12),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
          onPressed: () {
            setState(() {
              _messages.clear();
              _messages.add(ChatMessage(
                text: "Xin chào! Mình là Trợ lý ảo Tuyển sinh.\nMình có thể giúp gì cho bạn hôm nay? ✨",
                isUser: false,
                source: 'system',
              ));
            });
          },
        )
      ],
    );
  }

  // --- 2. BONG BÓNG CHAT (MESSAGE BUBBLE) ---
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('HH:mm').format(msg.time);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar Bot
          if (!isUser) ...[
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage('https://cdn-icons-png.flaticon.com/512/4712/4712035.png'),
              child: Icon(Icons.smart_toy, size: 20, color: Colors.blueAccent), 
            ),
            const SizedBox(width: 8),
          ],

          // Nội dung tin nhắn
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser && msg.source == 'faq')
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text("💡 Trả lời từ dữ liệu nhà trường", style: TextStyle(fontSize: 10, color: Colors.blue[800], fontStyle: FontStyle.italic)),
                  ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? null : Colors.white,
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], // Gradient Xanh -> Tím
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.5,
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                
                // Thời gian
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. THANH GỢI Ý (QUICK SUGGESTIONS) ---
  Widget _buildQuickSuggestions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              elevation: 0,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              label: Text(
                _quickQuestions[index],
                style: GoogleFonts.inter(color: Colors.blue[700], fontSize: 13),
              ),
              avatar: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.orange),
              onPressed: () => _sendMessage(text: _quickQuestions[index]),
            ),
          );
        },
      ),
    );
  }

  // --- 4. Ô NHẬP LIỆU (INPUT AREA) ---
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controller,
                enabled: !_isSending,
                decoration: InputDecoration(
                  hintText: "Nhập câu hỏi của bạn...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ],
              ),
              child: _isSending 
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. HIỆU ỨNG ĐANG GÕ (TYPING) ---
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text("Bot đang suy nghĩ...", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}