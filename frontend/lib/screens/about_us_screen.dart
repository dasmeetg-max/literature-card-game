// lib/screens/about_us_screen.dart
import 'package:flutter/material.dart';

// ── Design tokens ──────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ABOUT US',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutSection(
              title: 'Who we are',
              content:
                  'Literature Game is a passion project built by two friends, Ankur & Dasmeet, '
                  'who love card games and wanted to bring the classic game of '
                  'Literature to mobile — playable with friends and family, '
                  'anywhere in the world.',
            ),
            _AboutSection(
              title: 'Why we built this',
              content:
                  'Literature has always been one of those games that brings people '
                  'together — around a table, at a family gathering, or during a '
                  'late night with friends. We wanted to capture that same energy '
                  'and make it accessible to everyone, no matter where they are.',
            ),
            _AboutSection(
              title: 'Built with love',
              content:
                  'This app was designed and developed from scratch — every screen, '
                  'every card, every game mechanic. No shortcuts, just a genuine '
                  'effort to make something we\'d love to play ourselves.',
            ),
            _AboutSection(
              title: 'A note from us',
              content:
                  'We hope this game brings you as much joy as it brought us building it. '
                  'Whether you\'re playing with old friends or meeting new ones — '
                  'enjoy the game, trust your teammates, and may your sets be many.\n\n'
                  'Happy playing! 🃏',
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String content;

  const _AboutSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _peach,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: _border),
        ],
      ),
    );
  }
}
