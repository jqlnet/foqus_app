import 'package:flutter/material.dart';

void main() {
  runApp(const FoqusApp());
}

class FoqusApp extends StatelessWidget {
  const FoqusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foqus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE63946),
          surface: const Color(0xFF121212),
        ),
        fontFamily: 'serif',
      ),
      home: const LibraryScreen(),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Foqus',
          style: TextStyle(
            color: Color(0xFFE63946),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Your library is empty.\nAdd a book to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}