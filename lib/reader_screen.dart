import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'dart:async';

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
    super.dispose();
  }

  Future<void> loadWords() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final chapter = book.Chapters?[widget.chapterIndex];
      final content = chapter?.HtmlContent ?? '';

      // Strip HTML tags and extract plain text
      final plainText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final wordList = plainText
          .split(' ')
          .where((w) => w.trim().isNotEmpty)
          .toList();

      setState(() {
        words = wordList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void startReading() {
    final interval = Duration(milliseconds: (60000 / wpm).round());
    timer = Timer.periodic(interval, (t) {
      if (currentIndex < words.length - 1) {
        setState(() {
          currentIndex++;
        });
      } else {
        t.cancel();
        setState(() {
          isPlaying = false;
        });
      }
    });
    setState(() {
      isPlaying = true;
    });
  }

  void pauseReading() {
    timer?.cancel();
    setState(() {
      isPlaying = false;
    });
  }

  Widget buildWord(String word) {
    if (word.isEmpty) return const SizedBox();

    // Strip punctuation for ORP calculation only
    final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final calcWord = cleanWord.isEmpty ? word : cleanWord;

    int orpIndex;
    if (calcWord.length == 1) {
      orpIndex = 0;
    } else if (calcWord.length % 2 == 0) {
      orpIndex = (calcWord.length ~/ 2) - 1;
    } else {
      orpIndex = calcWord.length ~/ 2;
    }

    // Find the ORP character in the original word
    int actualOrpIndex = 0;
    int cleanCount = 0;
    for (int i = 0; i < word.length; i++) {
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(word[i])) {
        if (cleanCount == orpIndex) {
          actualOrpIndex = i;
          break;
        }
        cleanCount++;
      }
    }

    final before = word.substring(0, actualOrpIndex);
    final focus = word[actualOrpIndex];
    final after = word.substring(actualOrpIndex + 1);

    const style = TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w400,
      fontFamily: 'monospace',
      height: 1.0,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(before, style: style.copyWith(color: Colors.white)),
        Text(focus, style: style.copyWith(color: const Color(0xFFE63946))),
        Text(after, style: style.copyWith(color: Colors.white)),
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
                // Word display area
                Expanded(child: Center(child: buildWord(words[currentIndex]))),

                // Progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LinearProgressIndicator(
                    value: words.isEmpty ? 0 : currentIndex / words.length,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFE63946),
                  ),
                ),

                const SizedBox(height: 16),

                // WPM slider
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
                          value: wpm.toDouble(),
                          min: 100,
                          max: 800,
                          divisions: 14,
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

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rewind 10 words
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

                      // Play/Pause
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

                      // Skip 10 words
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
