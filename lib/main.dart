import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'library_screen.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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