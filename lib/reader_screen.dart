import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReaderScreen extends StatefulWidget {
  final String filePath;
  final int chapterIndex;

  const ReaderScreen({
    super.key,
    required this.filePath,
    required this.chapterIndex,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String> words = [];
  int currentIndex = 0;
  bool isPlaying = false;
  bool isLoading = true;
  int wpm = 250;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  @override
  void dispose() {
    timer?.cancel();
    saveProgress();
    super.dispose();
  }

  Future<void> loadWords() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapter = book.Chapters?[widget.chapterIndex];
      final content = chapter?.HtmlContent ?? '';

      final plainText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final rawTokens = plainText
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .toList();

      final List<String> wordList = [];
      final leadingQuoteRegex = RegExp(
        r'^[\u201C\u201D\u0022\u0027\u2018\u2019]+',
      );

      for (var token in rawTokens) {
        final m = leadingQuoteRegex.firstMatch(token);
        if (m != null) {
          final quotes = m.group(0)!;
          wordList.add(quotes);
          token = token.substring(quotes.length);
          if (token.isEmpty) continue;
        }

        if (token.endsWith('kun') && token.contains('-')) {
          final parts = token.split('-');
          if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            wordList.add(parts[0]);
            wordList.add('-');
            wordList.add(parts[1]);
            continue;
          }
        }

        if (token.contains('-')) {
          final segments = token.split('-');
          for (int i = 0; i < segments.length; i++) {
            final seg = segments[i];
            if (seg.isEmpty) continue;
            if (i > 0) wordList.add('-');
            wordList.add(seg);
          }
          continue;
        }

        wordList.add(token);
      }

      setState(() {
        words = wordList;
        isLoading = false;
      });
      await loadProgress();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('progress')
        .doc('${widget.filePath.replaceAll('/', '_')}_${widget.chapterIndex}')
        .set({
          'wordIndex': currentIndex,
          'totalWords': words.length,
          'filePath': widget.filePath,
          'chapterIndex': widget.chapterIndex,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> loadProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('progress')
        .doc('${widget.filePath.replaceAll('/', '_')}_${widget.chapterIndex}')
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['wordIndex'] != null) {
        setState(() {
          currentIndex = data['wordIndex'] as int;
        });
      }
    }
  }

  void startReading() {
    timer?.cancel();

    void scheduleNext() {
      if (!mounted) return;

      if (currentIndex >= words.length - 1) {
        setState(() => isPlaying = false);
        return;
      }

      final word = words[currentIndex];
      int baseMs = (60000 / wpm).round();
      int ms = baseMs;

      if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
        ms = (baseMs * 2.0).round();
      } else if (word.endsWith(',') ||
          word.endsWith(';') ||
          word.endsWith(':')) {
        ms = (baseMs * 1.5).round();
      } else if (word.length >= 8) {
        ms = (baseMs * 1.3).round();
      }

      timer = Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        setState(() {
          currentIndex++;
        });
        scheduleNext();
      });
    }

    setState(() => isPlaying = true);
    scheduleNext();
  }

  void pauseReading() {
    timer?.cancel();
    saveProgress();
    setState(() {
      isPlaying = false;
    });
  }

  Widget buildWord(String word) {
    if (word.isEmpty) return const SizedBox();

    // Dynamic font size based on word length
    double fontSize = 48;
    if (word.length > 8 && word.length <= 11) {
      fontSize = 38;
    } else if (word.length > 11 && word.length <= 14) {
      fontSize = 30;
    } else if (word.length > 14) {
      fontSize = 24;
    }

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: 'monospace',
      height: 1.0,
    );

    const double sideWidth = 160;

    // Short word fast-path
    if (word.length <= 2) {
      final mid = word.length == 1 ? 0 : 1;
      final before = word.substring(0, mid);
      final focus = word[mid];
      final after = word.substring(mid + 1);

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: sideWidth,
            child: Text(
              before,
              textAlign: TextAlign.right,
              style: style.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
          Text(focus, style: style.copyWith(color: const Color(0xFFE63946))),
          SizedBox(
            width: sideWidth,
            child: Text(
              after,
              textAlign: TextAlign.left,
              style: style.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      );
    }

    final punctuationRegex = RegExp(r"[a-zA-Z0-9\u0027\u2019\-]");

    final cleanWord = word
        .split('')
        .where((c) => punctuationRegex.hasMatch(c))
        .join();

    final calcWord = cleanWord.isEmpty ? word : cleanWord;

    int orpIndex;
    if (calcWord.length == 1) {
      orpIndex = 0;
    } else if (calcWord.length % 2 == 0) {
      orpIndex = (calcWord.length ~/ 2) - 1;
    } else {
      orpIndex = calcWord.length ~/ 2;
    }

    int? actualOrpIndex;
    int cleanCount = 0;
    for (int i = 0; i < word.length; i++) {
      if (punctuationRegex.hasMatch(word[i])) {
        if (cleanCount == orpIndex) {
          actualOrpIndex = i;
          break;
        }
        cleanCount++;
      }
    }

    actualOrpIndex ??= (word.length ~/ 2).clamp(0, word.length - 1);

    final before = word.substring(0, actualOrpIndex);
    final focus = word[actualOrpIndex];
    final after = word.substring(actualOrpIndex + 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: sideWidth,
          child: Text(
            before,
            textAlign: TextAlign.right,
            style: style.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
        Text(focus, style: style.copyWith(color: const Color(0xFFE63946))),
        SizedBox(
          width: sideWidth,
          child: Text(
            after,
            textAlign: TextAlign.left,
            style: style.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
            children: [
              TextSpan(
                text: 'FO',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Q',
                style: TextStyle(color: Color(0xFFE63946)),
              ),
              TextSpan(
                text: 'US',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE63946)),
            )
          : words.isEmpty
          ? const Center(
              child: Text(
                'No text found in this chapter.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : Column(
              children: [
                Expanded(child: Center(child: buildWord(words[currentIndex]))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: words.isEmpty
                              ? 0
                              : currentIndex / words.length,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFE63946),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        words.isEmpty
                            ? '0%'
                            : '${((currentIndex / words.length) * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text(
                        'WPM',
                        style: TextStyle(color: Colors.white54),
                      ),
                      Expanded(
                        child: Slider(
                          // the speed at which the reader goes through the words
                          value: wpm.toDouble(),
                          min: 100,
                          max: 1000,
                          divisions: 90,
                          activeColor: const Color(0xFFE63946),
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setState(() {
                              wpm = val.round();
                            });
                            if (isPlaying) {
                              pauseReading();
                              startReading();
                            }
                          },
                        ),
                      ),
                      Text(
                        '$wpm',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.replay_10,
                          color: Colors.white54,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            currentIndex = (currentIndex - 10).clamp(
                              0,
                              words.length - 1,
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: isPlaying ? pauseReading : startReading,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE63946),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(
                          Icons.forward_10,
                          color: Colors.white54,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            currentIndex = (currentIndex + 10).clamp(
                              0,
                              words.length - 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
