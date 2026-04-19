import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsSheet extends StatefulWidget {
  final int wpm;
  final Color bgColor;
  final Color orpColor;
  final Color textColor;
  final bool delayedMode;
  final bool sentenceMode;
  final Function(int) onWpmChanged;
  final Function(Color) onBgColorChanged;
  final Function(Color) onOrpColorChanged;
  final Function(Color) onTextColorChanged;
  final Function(bool) onDelayedModeChanged;
  final Function(bool) onSentenceModeChanged;

  const SettingsSheet({
    super.key,
    required this.wpm,
    required this.bgColor,
    required this.orpColor,
    required this.textColor,
    required this.delayedMode,
    required this.sentenceMode,
    required this.onWpmChanged,
    required this.onBgColorChanged,
    required this.onOrpColorChanged,
    required this.onTextColorChanged,
    required this.onDelayedModeChanged,
    required this.onSentenceModeChanged,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late int wpm;
  late Color bgColor;
  late Color orpColor;
  late Color textColor;
  late bool delayedMode;
  late bool sentenceMode;

  @override
  void initState() {
    super.initState();
    wpm = widget.wpm;
    bgColor = widget.bgColor;
    orpColor = widget.orpColor;
    textColor = widget.textColor;
    delayedMode = widget.delayedMode;
    sentenceMode = widget.sentenceMode;
  }

  Future<void> saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'wpm': wpm,
      'bgColor': bgColor.value,
      'orpColor': orpColor.value,
      'textColor': textColor.value,
      'delayedMode': delayedMode,
      'sentenceMode': sentenceMode,
    }, SetOptions(merge: true));
  }

  void showColorPickerDialog(String title, Color current, Function(Color) onChanged) {
    Color temp = current;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (color) => temp = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              setState(() => onChanged(temp));
              saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFE63946))),
          ),
        ],
      ),
    );
  }

  void showFaq() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('FAQ', style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('What is RSVP?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Rapid Serial Visual Presentation — words are shown one at a time to eliminate eye movement and increase reading speed.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('What is ORP?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Optimal Recognition Point — the key letter your brain focuses on to recognize a word. It is highlighted in your chosen color.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('Word Mode vs Sentence Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Word Mode shows one word at a time with ORP highlighting. Sentence Mode shows a full sentence at once — great for a more natural reading feel.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('What is Delayed Mode?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('When enabled, words with 8 or more letters are displayed at half your current WPM, giving your brain more time to process longer words.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('Reading Speed Guide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• Average reader: 200–250 WPM\n• Experienced reader: 300–500 WPM\n• Speed reader: 500–1000 WPM', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('Is my progress saved?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Yes! Your reading position, speed, and color settings are all saved to the cloud so you can pick up exactly where you left off on any device.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 16),
              Text('EPUB Compatibility', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Not all EPUB files are formatted the same way. Older or poorly structured EPUBs may display duplicate text or formatting inconsistencies. For best results, use EPUBs from reputable sources.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE63946))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: Color(0xFFE63946),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),

          // WPM Slider
          Row(
            children: [
              const Text('WPM', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: wpm.toDouble(),
                  min: 100,
                  max: 1000,
                  divisions: 900,
                  activeColor: const Color(0xFFE63946),
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    setState(() => wpm = val.round());
                    widget.onWpmChanged(wpm);
                    saveSettings();
                  },
                ),
              ),
              Text('$wpm', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),

          const Divider(color: Colors.white12),

          // Reading Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reading Mode', style: TextStyle(color: Colors.white, fontSize: 15)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => sentenceMode = false);
                      widget.onSentenceModeChanged(false);
                      saveSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !sentenceMode ? const Color(0xFFE63946) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE63946)),
                      ),
                      child: Text(
                        'Word',
                        style: TextStyle(
                          color: !sentenceMode ? Colors.white : const Color(0xFFE63946),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => sentenceMode = true);
                      widget.onSentenceModeChanged(true);
                      saveSettings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sentenceMode ? const Color(0xFFE63946) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE63946)),
                      ),
                      child: Text(
                        'Sentence',
                        style: TextStyle(
                          color: sentenceMode ? Colors.white : const Color(0xFFE63946),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Delayed Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Delayed Mode', style: TextStyle(color: Colors.white, fontSize: 15)),
                  Text('Slows down 8+ letter words', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              Switch(
                value: delayedMode,
                activeColor: const Color(0xFFE63946),
                onChanged: (val) {
                  setState(() => delayedMode = val);
                  widget.onDelayedModeChanged(val);
                  saveSettings();
                },
              ),
            ],
          ),

          const Divider(color: Colors.white12),

          // Color Options
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: bgColor, radius: 12),
            title: const Text('Background Color', style: TextStyle(color: Colors.white)),
            onTap: () => showColorPickerDialog('Background Color', bgColor, (c) {
              bgColor = c;
              widget.onBgColorChanged(c);
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: orpColor, radius: 12),
            title: const Text('Highlight Color', style: TextStyle(color: Colors.white)),
            onTap: () => showColorPickerDialog('Highlight Color', orpColor, (c) {
              orpColor = c;
              widget.onOrpColorChanged(c);
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: textColor, radius: 12),
            title: const Text('Text Color', style: TextStyle(color: Colors.white)),
            onTap: () => showColorPickerDialog('Text Color', textColor, (c) {
              textColor = c;
              widget.onTextColorChanged(c);
            }),
          ),

          const Divider(color: Colors.white12),

          // FAQ
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: Colors.white54),
            title: const Text('FAQ', style: TextStyle(color: Colors.white)),
            onTap: showFaq,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}