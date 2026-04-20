import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final String filePath;
  final int chapterIndex;
  final Color bgColor;
  final Color orpColor;
  final Color textColor;
  final bool delayedMode;
  final bool sentenceMode;

  const ReaderScreen({
    super.key,
    required this.filePath,
    required this.chapterIndex,
    required this.bgColor,
    required this.orpColor,
    required this.textColor,
    required this.delayedMode,
    required this.sentenceMode,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String> words = [];
  List<String> sentences = [];
  int currentIndex = 0;
  int currentSentenceIndex = 0;
  bool isPlaying = false;
  bool isLoading = true;
  int wpm = 250;
  Timer? timer;
  late Color bgColor;
  late Color orpColor;
  late Color textColor;
  late bool delayedMode;
  late bool sentenceMode;

  @override
  void initState() {
    super.initState();
    bgColor = widget.bgColor;
    orpColor = widget.orpColor;
    textColor = widget.textColor;
    delayedMode = widget.delayedMode;
    sentenceMode = widget.sentenceMode;
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
          .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), ' ')
          .replaceAll(RegExp(r'<h[1-6][^>]*>.*?</h[1-6]>', caseSensitive: false, dotAll: true), ' ')
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

      // Build sentences by grouping words
      final List<String> sentenceList = [];
      List<String> currentSentence = [];
      for (var word in wordList) {
        currentSentence.add(word);
        if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
          sentenceList.add(currentSentence.join(' '));
          currentSentence = [];
        }
      }
      if (currentSentence.isNotEmpty) {
        sentenceList.add(currentSentence.join(' '));
      }

      setState(() {
        words = wordList;
        sentences = sentenceList;
        isLoading = false;
      });
      await loadProgress();
      await loadWpm();
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

  Future<void> saveWpm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'wpm': wpm}, SetOptions(merge: true));
  }

  int getWordMs(String word) {
    int baseMs = (60000 / wpm).round();
    int ms = baseMs;

    if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
      ms = (baseMs * 2.0).round();
    } else if (word.endsWith(',') || word.endsWith(';') || word.endsWith(':')) {
      ms = (baseMs * 1.5).round();
    } else if (delayedMode && word.length >= 8) {
      final halfWpm = (wpm / 2).floor();
      ms = (60000 / halfWpm).round();
    } else if (word.length >= 8) {
      ms = (baseMs * 1.3).round();
    }

    return ms;
  }

  void startReading() {
    timer?.cancel();

    if (sentenceMode) {
      _startSentenceMode();
    } else {
      _startWordMode();
    }

    setState(() => isPlaying = true);
  }

  void _startWordMode() {
    void scheduleNext() {
      if (!mounted) return;
      if (currentIndex >= words.length - 1) {
        setState(() => isPlaying = false);
        return;
      }

      final word = words[currentIndex];
      final ms = getWordMs(word);

      timer = Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        setState(() => currentIndex++);
        scheduleNext();
      });
    }

    scheduleNext();
  }

  void _startSentenceMode() {
    void scheduleNext() {
      if (!mounted) return;
      if (currentSentenceIndex >= sentences.length - 1) {
        setState(() => isPlaying = false);
        return;
      }

      final sentence = sentences[currentSentenceIndex];
      final sentenceWords = sentence.split(' ');
      final totalMs = sentenceWords.fold<int>(0, (sum, w) => sum + getWordMs(w));

      timer = Timer(Duration(milliseconds: totalMs), () {
        if (!mounted) return;
        setState(() => currentSentenceIndex++);
        scheduleNext();
      });
    }

    scheduleNext();
  }

  void pauseReading() {
    timer?.cancel();
    saveProgress();
    setState(() => isPlaying = false);
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
        onWpmChanged: (val) {
          setState(() => wpm = val);
          saveWpm();
          if (isPlaying) {
            pauseReading();
            startReading();
          }
        },
        onBgColorChanged: (val) => setState(() => bgColor = val),
        onOrpColorChanged: (val) => setState(() => orpColor = val),
        onTextColorChanged: (val) => setState(() => textColor = val),
        onDelayedModeChanged: (val) => setState(() => delayedMode = val),
        onSentenceModeChanged: (val) {
          setState(() => sentenceMode = val);
          if (isPlaying) {
            pauseReading();
            startReading();
          }
        },
      ),
    );
  }

  Widget buildWord(String word) {
    if (word.isEmpty) return const SizedBox();

    double fontSize = 48;
    if (word.length > 8 && word.length <= 11) fontSize = 38;
    else if (word.length > 11 && word.length <= 14) fontSize = 30;
    else if (word.length > 14) fontSize = 24;

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontFamily: 'monospace',
      height: 1.0,
    );

    const double sideWidth = 160;

    if (word.length <= 2) {
      final mid = word.length == 1 ? 0 : 1;
      final before = word.substring(0, mid);
      final focus = word[mid];
      final after = word.substring(mid + 1);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: sideWidth, child: Text(before, textAlign: TextAlign.right, style: style.copyWith(color: textColor), maxLines: 1, overflow: TextOverflow.visible)),
          Text(focus, style: style.copyWith(color: orpColor)),
          SizedBox(width: sideWidth, child: Text(after, textAlign: TextAlign.left, style: style.copyWith(color: textColor), maxLines: 1, overflow: TextOverflow.visible)),
        ],
      );
    }

    final punctuationRegex = RegExp(r"[a-zA-Z0-9\u0027\u2019\-]");
    final cleanWord = word.split('').where((c) => punctuationRegex.hasMatch(c)).join();
    final calcWord = cleanWord.isEmpty ? word : cleanWord;

    int orpIndex;
    if (calcWord.length == 1) orpIndex = 0;
    else if (calcWord.length % 2 == 0) orpIndex = (calcWord.length ~/ 2) - 1;
    else orpIndex = calcWord.length ~/ 2;

    int? actualOrpIndex;
    int cleanCount = 0;
    for (int i = 0; i < word.length; i++) {
      if (punctuationRegex.hasMatch(word[i])) {
        if (cleanCount == orpIndex) { actualOrpIndex = i; break; }
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
        SizedBox(width: sideWidth, child: Text(before, textAlign: TextAlign.right, style: style.copyWith(color: textColor), maxLines: 1, overflow: TextOverflow.visible)),
        Text(focus, style: style.copyWith(color: orpColor)),
        SizedBox(width: sideWidth, child: Text(after, textAlign: TextAlign.left, style: style.copyWith(color: textColor), maxLines: 1, overflow: TextOverflow.visible)),
      ],
    );
  }

  Widget buildSentence(String sentence) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        sentence,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          color: textColor,
          fontFamily: 'monospace',
          height: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = sentenceMode ? sentences.length : words.length;
    final currentItem = sentenceMode ? currentSentenceIndex : currentIndex;
    final progress = totalItems == 0 ? 0.0 : currentItem / totalItems;
    final progressText = totalItems == 0 ? '0%' : '${(progress * 100).round()}%';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor.withOpacity(0.54)),
            color: const Color(0xFF1a1a1a),
            onSelected: (value) {
              if (value == 'settings') openSettings();
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
            ],
          ),
        ],
        title: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3),
            children: [
              TextSpan(text: 'FO', style: TextStyle(color: textColor)),
              TextSpan(text: 'Q', style: TextStyle(color: orpColor)),
              TextSpan(text: 'US', style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: orpColor))
          : (sentenceMode ? sentences.isEmpty : words.isEmpty)
              ? const Center(child: Text('No text found.', style: TextStyle(color: Colors.white38)))
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: sentenceMode
                            ? buildSentence(sentences[currentSentenceIndex])
                            : buildWord(words[currentIndex]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white12,
                              color: orpColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(progressText, style: TextStyle(color: textColor.withOpacity(0.54), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text('WPM', style: TextStyle(color: textColor.withOpacity(0.54))),
                          Expanded(
                            child: Slider(
                              value: wpm.toDouble(),
                              min: 100,
                              max: 1000,
                              divisions: 900,
                              activeColor: orpColor,
                              inactiveColor: Colors.white12,
                              onChanged: (val) {
                                setState(() => wpm = val.round());
                                saveWpm();
                                if (isPlaying) { pauseReading(); startReading(); }
                              },
                            ),
                          ),
                          Text('$wpm', style: TextStyle(color: textColor.withOpacity(0.54))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.replay_10, color: textColor.withOpacity(0.54), size: 36),
                            onPressed: () {
                              setState(() {
                                if (sentenceMode) {
                                  currentSentenceIndex = (currentSentenceIndex - 1).clamp(0, sentences.length - 1);
                                } else {
                                  currentIndex = (currentIndex - 10).clamp(0, words.length - 1);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: isPlaying ? pauseReading : startReading,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: orpColor, shape: BoxShape.circle),
                              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: bgColor, size: 36),
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(Icons.forward_10, color: textColor.withOpacity(0.54), size: 36),
                            onPressed: () {
                              setState(() {
                                if (sentenceMode) {
                                  currentSentenceIndex = (currentSentenceIndex + 1).clamp(0, sentences.length - 1);
                                } else {
                                  currentIndex = (currentIndex + 10).clamp(0, words.length - 1);
                                }
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