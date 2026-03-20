import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'reader_screen.dart';

class ChapterScreen extends StatefulWidget {
  final String filePath;

  const ChapterScreen({super.key, required this.filePath});

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  List<String> chapters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  Future<void> loadChapters() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapterList = book.Chapters;

      setState(() {
        chapters =
            chapterList
                ?.where((c) => c.Title != null)
                .map((c) => c.Title!)
                .toList() ??
            [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SELECT CHAPTER',
          style: TextStyle(
            color: Color(0xFFE63946),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE63946)),
            )
          : chapters.isEmpty
          ? const Center(
              child: Text(
                'No chapters found.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    chapters[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFFE63946),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(
                          filePath: widget.filePath,
                          chapterIndex: index,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
