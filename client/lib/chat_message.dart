class ChatMessage {
  final String text;     // nội dung tin nhắn
  final bool isUser;     // true: người dùng, false: bot
  final String? source;  // 'faq', 'ai', 'system' hoặc null
  final int? faqId;      // id FAQ (nếu có)
  final String? topic;   // chủ đề FAQ (nếu có)

  ChatMessage({
    required this.text,
    required this.isUser,
    this.source,
    this.faqId,
    this.topic,
  });
}
