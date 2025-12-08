import 'package:flutter/material.dart';
import 'screens/chat_screen.dart'; // Import file màn hình chat vừa tạo

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Tắt chữ Debug ở góc
      title: 'School Chatbot',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(), // Gọi màn hình ChatScreen ra chạy
    );
  }
}