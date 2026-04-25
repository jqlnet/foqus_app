import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'library_screen.dart';
import 'auth_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized
  }
  await GoogleSignIn.instance.initialize();
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A0A0A),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFE63946)),
              ),
            );
          }
          if (snapshot.hasData) {
            return const LibraryScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
