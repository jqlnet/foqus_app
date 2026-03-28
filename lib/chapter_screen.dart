import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reader_screen.dart';

class ChapterScreen extends StatefulWidget {
  final String filePath;
  final Color bgColor;
  final Color orpColor;
  final Color textColor;

  const ChapterScreen({
    super.key,
    required this.filePath,
    required this.bgColor,
    required this.orpColor,
    required this.textColor,
  });

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  List<String> chapters = [];
  Map<int, int> chapterProgress = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChapters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadChapters();
  }

  Future<void> loadChapters() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapterList = book.Chapters;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final progressSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .get();

        final Map<int, int> progress = {};
        for (var doc in progressSnapshot.docs) {
          final data = doc.data();
          if (data['filePath'] == widget.filePath) {
            final chapterIndex = data['chapterIndex'] as int;
            final wordIndex = data['wordIndex'] as int;
            final totalWords = data['totalWords'] as int;
            if (totalWords > 0) {
              progress[chapterIndex] = ((wordIndex / totalWords) * 100).round();
            }
          }
        }

        if (mounted) {
          setState(() {
            chapterProgress = progress;
          });
        }
      }

      if (mounted) {
        setState(() {
          chapters = chapterList
                  ?.where((c) => c.Title != null)
                  .map((c) => c.Title!)
                  .toList() ??
              [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
              : RefreshIndicator(
                  color: const Color(0xFFE63946),
                  backgroundColor: const Color(0xFF1a1a1a),
                  onRefresh: loadChapters,
                  child: ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final progress = chapterProgress[index];
                      return ListTile(
                        title: Text(
                          chapters[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: progress != null && progress > 0
                            ? Text(
                                '$progress% completed',
                                style: const TextStyle(
                                  color: Color(0xFFE63946),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        leading: const Icon(
                          Icons.article_outlined,
                          color: Color(0xFFE63946),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReaderScreen(
                                filePath: widget.filePath,
                                chapterIndex: index,
                                bgColor: widget.bgColor,
                                orpColor: widget.orpColor,
                                textColor: widget.textColor,
                              ),
                            ),
                          );
                          loadChapters();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}