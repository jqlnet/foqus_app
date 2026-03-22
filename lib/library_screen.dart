import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'chapter_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> books = [];
  bool isLoading = true;
  int wpm = 250;

  @override
  void initState() {
    super.initState();
    loadBooks();
    loadWpm();
  }

  Future<void> loadWpm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()?['wpm'] != null) {
      setState(() {
        wpm = doc.data()!['wpm'] as int;
      });
    }
  }

  Future<void> saveWpm(int newWpm) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'wpm': newWpm,
    }, SetOptions(merge: true));

    setState(() {
      wpm = newWpm;
    });
  }

  Future<void> loadBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('books')
        .get();

    setState(() {
      books = snapshot.docs.map((doc) => doc['filePath'] as String).toList();
      isLoading = false;
    });
  }

  Future<void> pickBook() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result != null) {
      String? tempPath = result.files.single.path;
      if (tempPath == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = result.files.single.name;
      final permanentPath = '${appDir.path}/$fileName';

      if (books.contains(permanentPath)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This book is already in your library!'),
          ),
        );
        return;
      }

      await File(tempPath).copy(permanentPath);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('books')
          .add({'filePath': permanentPath});

      setState(() {
        books.add(permanentPath);
      });
    }
  }

  void showWpmDialog() {
    int tempWpm = wpm;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          title: const Text(
            'Reading Speed',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$tempWpm WPM',
                style: const TextStyle(
                  color: Color(0xFFE63946),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: tempWpm.toDouble(),
                min: 100,
                max: 1000,
                divisions: 90,
                activeColor: const Color(0xFFE63946),
                inactiveColor: Colors.white12,
                onChanged: (val) {
                  setDialogState(() {
                    tempWpm = val.round();
                  });
                },
              ),
              const Text(
                'Average reader: 200-250 WPM',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Experienced reader: 300-500 WPM',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Speed reader: 500+ WPM',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                saveWpm(tempWpm);
                Navigator.pop(context);
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Color(0xFFE63946)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FOQUS',
          style: TextStyle(
            color: Color(0xFFE63946),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white38),
            color: const Color(0xFF1a1a1a),
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
              } else if (value == 'wpm') {
                showWpmDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'wpm',
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Reading Speed ($wpm WPM)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE63946)),
            )
          : books.isEmpty
          ? const Center(
              child: Text(
                'Your library is empty.\nAdd a book to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: Key(books[index]),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: const Color(0xFF1a0505),
                    child: const Icon(Icons.delete, color: Color(0xFFE63946)),
                  ),
                  onDismissed: (direction) async {
                    final removedBook = books[index];

                    setState(() {
                      books.removeAt(index);
                    });

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final snapshot = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('books')
                        .where('filePath', isEqualTo: removedBook)
                        .get();

                    for (var doc in snapshot.docs) {
                      await doc.reference.delete();
                    }

                    await File(removedBook).delete();
                  },
                  child: ListTile(
                    title: Text(
                      books[index].split('/').last,
                      style: const TextStyle(color: Colors.white),
                    ),
                    leading: const Icon(Icons.book, color: Color(0xFFE63946)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ChapterScreen(filePath: books[index]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickBook,
        backgroundColor: Colors.red,
        elevation: 10,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
