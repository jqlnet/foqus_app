import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'chapter_screen.dart';
import 'settings_sheet.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<String> books = [];
  Map<String, Uint8List?> bookCovers = {};
  bool isLoading = true;
  int wpm = 250;
  Color bgColor = const Color(0xFF0A0A0A);
  Color orpColor = const Color(0xFFE63946);
  Color textColor = Colors.white;
  bool delayedMode = false;
  bool sentenceMode = false;

  @override
  void initState() {
    super.initState();
    loadBooks();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        if (data?['wpm'] != null) wpm = data!['wpm'] as int;
        if (data?['bgColor'] != null) bgColor = Color(data!['bgColor'] as int);
        if (data?['orpColor'] != null)
          orpColor = Color(data!['orpColor'] as int);
        if (data?['textColor'] != null)
          textColor = Color(data!['textColor'] as int);
        if (data?['delayedMode'] != null)
          delayedMode = data!['delayedMode'] as bool;
        if (data?['sentenceMode'] != null)
          sentenceMode = data!['sentenceMode'] as bool;
      });
    }
  }

  Future<void> loadBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('books')
        .get();

    if (!mounted) return;

    final loadedBooks = snapshot.docs
        .map((doc) => doc['filePath'] as String)
        .toList();

    setState(() {
      books = loadedBooks;
      isLoading = false;
    });

    for (final path in loadedBooks) {
      _loadCover(path);
    }
  }

Future<void> _loadCover(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final cover = book.CoverImage;
    if (cover != null) {
      final coverBytes = await compute(_encodeImage, cover);
      if (mounted) {
        setState(() => bookCovers[filePath] = coverBytes);
      }
    } else {
      if (mounted) setState(() => bookCovers[filePath] = null);
    }
  } catch (e) {
    if (mounted) setState(() => bookCovers[filePath] = null);
  }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This book is already in your library!'),
            ),
          );
        }
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

      _loadCover(permanentPath);
    }
  }

  void openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SettingsSheet(
        wpm: wpm,
        bgColor: bgColor,
        orpColor: orpColor,
        textColor: textColor,
        delayedMode: delayedMode,
        sentenceMode: sentenceMode,
        onWpmChanged: (val) => setState(() => wpm = val),
        onBgColorChanged: (val) => setState(() => bgColor = val),
        onOrpColorChanged: (val) => setState(() => orpColor = val),
        onTextColorChanged: (val) => setState(() => textColor = val),
        onDelayedModeChanged: (val) => setState(() => delayedMode = val),
        onSentenceModeChanged: (val) => setState(() => sentenceMode = val),
      ),
    );
  }

  Widget _buildCover(String filePath) {
    final cover = bookCovers[filePath];
    if (cover != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(cover, width: 50, height: 75, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 50,
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE63946), width: 1),
      ),
      child: const Icon(Icons.book, color: Color(0xFFE63946), size: 28),
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
              if (value == 'settings') {
                openSettings();
              } else if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: Colors.white)),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      books[index].split('/').last.replaceAll('.epub', ''),
                      style: const TextStyle(color: Colors.white),
                    ),
                    leading: _buildCover(books[index]),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChapterScreen(
                            filePath: books[index],
                            bgColor: bgColor,
                            orpColor: orpColor,
                            textColor: textColor,
                            delayedMode: delayedMode,
                            sentenceMode: sentenceMode,
                            coverImage: bookCovers[books[index]],
                          ),
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

Uint8List _encodeImage(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}
