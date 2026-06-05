// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';

// ── Design tokens ──────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'PRIVACY POLICY',
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
            _PolicySection(
              title: 'Last updated',
              content: 'March 2026',
            ),
            _PolicySection(
              title: '1. Overview',
              content:
                  'Literature Game ("we," "us," or "our") is a multiplayer card game. '
                  'We are committed to protecting your privacy. This policy explains what '
                  'information we collect, how we use it, and your rights regarding that information.',
            ),
            _PolicySection(
              title: '2. Information We Collect',
              content:
                  'We believe in data minimization. We collect only the minimum information '
                  'required to facilitate a functional multiplayer game session:\n\n'
                  '• Display Name: The temporary name you enter when creating or joining a room. '
                  'This is visible only to other players in your specific game session.\n\n'
                  '• Room Code: A temporary, system-generated code used to connect players in a session.\n\n'
                  'No Account Required: Literature Game does not require you to create an account, '
                  'register, or provide an email address to play.\n\n'
                  'What we do NOT collect: We do not collect your real name, email address, '
                  'phone number, precise location, device identifiers (IMEI/ADID), or any other '
                  'sensitive personal information.',
            ),
            _PolicySection(
              title: '3. How We Use Your Information',
              content:
                  'Your display name and room code are used solely to facilitate the multiplayer game session.\n\n'
                  '• Temporary Storage: This data is stored temporarily in the server\'s volatile memory (RAM).\n'
                  '• Automatic Deletion: All session data is automatically purged when the game session ends '
                  'or after 30 minutes of inactivity.',
            ),
            _PolicySection(
              title: '4. Data Storage and Tracking',
              content:
                  'We do not store any personal data in a permanent database.\n\n'
                  '• No Persistence: All session data exists only for the duration of the active game.\n'
                  '• No Tracking: We do not use cookies, local storage, or web beacons to track users '
                  'across sessions or across the web.',
            ),
            _PolicySection(
              title: '5. Security and Device Permissions',
              content:
                  'We value your trust in providing your temporary session data and ensure it is handled securely.\n\n'
                  '• Data in Transit: All communication between your device and our servers is encrypted in '
                  'transit using standard security protocols (such as HTTPS/TLS).\n'
                  '• Device Permissions: To function as a multiplayer game, the app requires standard network '
                  'permissions to access the internet. This connection is used exclusively to communicate with '
                  'our game servers and sync gameplay; it is not used to access or transmit other personal data '
                  'from your device.',
            ),
            _PolicySection(
              title: '6. Third-Party Services',
              content:
                  'We value your privacy and do not monetize your data.\n\n'
                  '• No Sharing: We do not sell, share, or transfer your information to any third parties.\n'
                  '• No Analytics/Ads: We do not use third-party analytics (like Google Analytics), '
                  'advertising networks, or tracking services within the app.',
            ),
            _PolicySection(
              title: '7. Children\'s Privacy',
              content:
                  'Literature Game is designed to be suitable for all ages. Because we do not collect '
                  'persistent "Personal Information" as defined by COPPA (such as email, phone number, '
                  'or location), and we only use temporary display names chosen by the user for session '
                  'functionality, no formal parental consent is required to use the app. We do not '
                  'knowingly collect or store any personal information from children.',
            ),
            _PolicySection(
              title: '8. Your Rights and Data Deletion',
              content:
                  'Under various global privacy laws (such as GDPR or CCPA), users have the right to request '
                  'the deletion of their accounts and associated data.\n\n'
                  'Because Literature Game does not utilize user accounts and does not store any personal '
                  'data permanently, there is no user data or account to be requested, modified, or deleted. '
                  'Your data is effectively "forgotten" by our systems the moment your session ends.',
            ),
            _PolicySection(
              title: '9. Changes to This Policy',
              content:
                  'We reserve the right to modify or update this privacy policy at any time, at our sole '
                  'discretion, and whenever required to reflect changes in our app, legal requirements, or '
                  'business practices. Any changes will be effective immediately upon posting the updated '
                  'policy, which will be reflected by a revised "Last updated" date at the top of this document. '
                  'Your continued use of the game after any changes indicates your acceptance of the updated '
                  'policy. We encourage you to review this page periodically.',
            ),
            _PolicySection(
              title: '10. Contact Us',
              content:
                  'If you have any questions or concerns about this privacy policy, please reach out to us '
                  'using the contact details provided on our official app store listing.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

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
