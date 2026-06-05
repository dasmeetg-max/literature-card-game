import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/socket_service.dart';
import 'screens/onboarding_screen.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/pre_game_screen.dart';
import 'screens/game_board_screen.dart';
import 'screens/game_over_screen.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const LiteratureApp());
  });
}

class LiteratureApp extends StatefulWidget {
  const LiteratureApp({super.key});

  @override
  State<LiteratureApp> createState() => _LiteratureAppState();
}

class _LiteratureAppState extends State<LiteratureApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Globally wake up the socket whenever the app returns from background/locked screen
      try {
        SocketService.instance.reconnectExisting();
      } catch (e) {
        // Silently fail if socket isn't initialized yet
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Literature App',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

// THE ROUTER MAP
final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),

    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    GoRoute(
      path: '/',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const PreGameScreens(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              // Curve.easeInOut ensures it starts slow, speeds up, and slows down
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) {
        final gameData =
            state.extra as Map<String, dynamic>? ?? <String, dynamic>{};
        return GameBoardScreen(initialGameData: gameData);
      },
    ),
    GoRoute(
      path: '/game-over',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return GameOverScreen(
          scoreA: data['scoreA'],
          scoreB: data['scoreB'],
          winner: data['winner'],
          isDraw: data['isDraw'],
          teamAName: data['teamAName'],
          teamBName: data['teamBName'],
          roomCode: data['roomCode'],
          playerCount: data['playerCount'] ?? 6,
          playerName: data['playerName'] ?? '',
        );
      },
    ),
  ],
);
