import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // TRADE-OFF: The duration your logo stays on screen after Flutter loads.
  // 1500ms feels intentional. <1000ms feels rushed. >2500ms annoys users.
  final int _splashDelay = 1500;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  void _startSplashSequence() {
    // 1. Wait until the first frame is painted on the screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 2. Remove the native splash screen. Because this widget looks exactly
      // the same, the user will not notice the swap.
      FlutterNativeSplash.remove();

      // 3. Wait for your desired aesthetic delay
      await Future.delayed(Duration(milliseconds: _splashDelay));

      // 4. Navigate safely if the widget is still mounted
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1A10), // Exactly matches YAML hex
      body: Center(
        // TRADE-OFF: Image width.
        // You MUST tweak this number (e.g., 200, 250, 300) until the size
        // perfectly matches how big the OS rendered the native logo.
        child: SizedBox(
          width: 250,
          child: Image.asset(
            'assets/splash_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
