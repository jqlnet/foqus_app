import 'package:flutter/material.dart'; 
import 'library_screen.dart'; // now the library screen is imported here, so we can use it as the home of our app.

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

