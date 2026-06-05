// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Design tokens ──────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
// const _surface = Color(0xFF15281A);
const _elevated = Color(0xFF1E3824);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);
const _textHint = Color(0xFF4A6E50);

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedType = 'Bug Report';
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  static const String _formUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSdZHNu7s1cEioo6jSbIZSeXdXapiq9mrDjDlUM4WZdPtDDlHA/formResponse';

  Future<void> _submitFeedback() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description.',
              style: TextStyle(color: _textPrimary)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await http.post(
        Uri.parse(_formUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'entry.1154319063': _selectedType,
          'entry.2099991395': _descriptionController.text.trim(),
          'entry.165901392': _nameController.text.trim(),
        },
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit. Please try again.',
                style: TextStyle(color: _textPrimary)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildThankYou() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: _peach, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Thank you!',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your feedback has been received.\nWe really appreciate you taking the time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _elevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Menu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TYPE',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Bug Report', 'Feedback'].map((type) {
              bool isSelected = _selectedType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin:
                        EdgeInsets.only(right: type == 'Bug Report' ? 10 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? _peach.withValues(alpha: 0.9) : _elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _peach : _border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == 'Bug Report'
                                ? Icons.bug_report_outlined
                                : Icons.star_outline,
                            color: isSelected
                                ? const Color(0xFF3A1A00)
                                : _textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF3A1A00)
                                  : _textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            maxLines: 6,
            style: const TextStyle(color: _textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: _selectedType == 'Bug Report'
                  ? 'Describe what happened and how to reproduce it...'
                  : 'Share your thoughts, suggestions, or ideas...',
              hintStyle: const TextStyle(color: _textHint),
              filled: true,
              fillColor: _elevated,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _peach, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'YOUR NAME (OPTIONAL)',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: _textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'So we know who to thank...',
              hintStyle: const TextStyle(color: _textHint),
              filled: true,
              fillColor: _elevated,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _peach, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: _peach,
                disabledBackgroundColor: _elevated,
                foregroundColor: const Color(0xFF3A1A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Color(0xFF3A1A00),
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'Submit Feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

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
          'FEEDBACK',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isSubmitted ? _buildThankYou() : _buildForm(),
      ),
    );
  }
}
