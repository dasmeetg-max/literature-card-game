// lib/screens/pre_game_screen.dart
// ─────────────────────────────────────────────────────────────────
//  PRE-GAME SCREEN — Home + Lobby views
//
//  CHANGES IN THIS VERSION:
//    1. Top bar (avatar / title / settings) removed
//    2. Bottom nav bar removed
//    3. Hero banner replaced with app logo PNG (_LogoBanner)
//    4. Join flow → single center dialog asking room code + name
//    5. Host flow → center dialog (not bottom sheet) asking name
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/socket_service.dart';
import 'rules_screen.dart';
import 'feedback_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_us_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens ──────────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _surface = Color(0xFF15281A);
const _elevated = Color(0xFF1E3824);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);
const _textHint = Color(0xFF4A6E50);

// ─────────────────────────────────────────────────────────────────
//  ROOT WIDGET
// ─────────────────────────────────────────────────────────────────

class PreGameScreens extends StatefulWidget {
  const PreGameScreens({super.key});

  @override
  State<PreGameScreens> createState() => _PreGameScreensState();
}

class _PreGameScreensState extends State<PreGameScreens>
    with WidgetsBindingObserver {
  // ── State ─────────────────────────────────────────────────────
  String currentScreen = 'home';
  String playerName = '';
  String roomCode = '';
  bool isHost = false;
  bool isBotGame = false;
  String? hostName;
  late AppLinks _appLinks;

  List<Map<String, dynamic>> players = [];
  String? myTeam;

  // Set by the server via 'roomFormat' after creating or joining a room.
  // playerCount = total players (4 or 6), teamSize = players per team (2 or 3).
  // Defaults to 6-player until the server tells us otherwise.
  int playerCount = 6;
  int teamSize = 3;

  final String blueTeamName = "TEAM BLUE";
  final String redTeamName = "TEAM RED";

  final String serverUrl = 'https://literatureserver-production.up.railway.app/';
  // final String serverUrl = 'http://localhost:3000';

  List<String> get blueTeam => players
      .where((p) => p['team'] == blueTeamName)
      .map((p) => p['name'] as String)
      .toList();

  List<String> get redTeam => players
      .where((p) => p['team'] == redTeamName)
      .map((p) => p['name'] as String)
      .toList();

  // ── Lifecycle ─────────────────────────────────────────────────

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  SocketService.instance.connectToServer(serverUrl);
  _setupSocketListeners();
  _initDeepLinks();
  _checkAutoPilot();
  _checkOnboarding(); // ✅ add this
}

Future<void> _checkOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  final done = prefs.getBool('onboarding_done') ?? false;
  if (!done && mounted) {
    context.go('/onboarding');
  }
}
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService.instance.socket.off('roomCreated');
    SocketService.instance.socket.off('playerJoined');
    SocketService.instance.socket.off('currentPlayers');
    SocketService.instance.socket.off('initGame');
    SocketService.instance.socket.off('createRoomError');
    SocketService.instance.socket.off('joinRoomError');
    SocketService.instance.socket.off('userNameExistError');
    SocketService.instance.socket.off('teamFull');
    SocketService.instance.socket.off('startGameError');
    SocketService.instance.socket.off('waitingReconnected');
    SocketService.instance.socket.off('reconnected');
    SocketService.instance.socket.off('roomFormat');
    SocketService.instance.socket.off('connect_error');
    SocketService.instance.socket.off('disconnect');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ✅ CRITICAL BUG FIX:
      // Removed manual connectToServer() and delayed emit('joinRoom').
      // main.dart and SocketService automatically handle background reconnection.
      // Doing it here caused duplicate connections and event spamming.
      debugPrint(
          '🔄 [PRE-GAME] App resumed. Trusting SocketService to manage connection.');
    }
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Cold start — wait for widget to be fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && mounted) {
        debugPrint('🔗 Cold start deep link: $uri');
        _handleDeepLink(uri);
      }
    });

    // App already open — link clicked while running
    _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        debugPrint('🔗 Foreground deep link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    final room = uri.queryParameters['room'];
    if (room != null && room.isNotEmpty && mounted) {
      debugPrint('🔗 Deep link received — Room: $room');
      // Small delay to ensure home screen is fully rendered
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (_) => _JoinDialog(
            initialRoomCode: room,
            onConfirmed: (code, name) {
              setState(() {
                playerName = name;
                roomCode = code;
              });
              SocketService.instance.saveSession(name, code);
              SocketService.instance.emit('joinRoom', {
                'name': name,
                'room': code,
              });
            },
          ),
        );
      });
    }
  }

  // ── Auto-pilot ────────────────────────────────────────────────

  void _checkAutoPilot() {
    try {
      final uri = Uri.base;
      if (uri.queryParameters['autoJoin'] == 'true') {
        final bName = uri.queryParameters['name'] ?? '';
        final bRoom = uri.queryParameters['room'] ?? '';
        final bTeam = uri.queryParameters['team'];

        if (bName.isNotEmpty && bRoom.isNotEmpty) {
          setState(() {
            playerName = bName;
            roomCode = bRoom;
            currentScreen = 'lobby';
          });

          Future.delayed(const Duration(milliseconds: 1000), () {
            SocketService.instance
                .emit('joinRoom', {'name': bName, 'room': bRoom});
            if (bTeam != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                SocketService.instance
                    .emit('pickTeam', {'room': bRoom, 'team': bTeam});
              });
            }
          });
        }
      }
    } catch (_) {}
  }

  // ── Socket listeners ──────────────────────────────────────────

  void _setupSocketListeners() {
    final socket = SocketService.instance;

    socket.on('roomCreated', (data) {
      if (!mounted) return;
      final code = data['code'] as String;
      SocketService.instance.saveSession(playerName, code);
      setState(() {
        roomCode = code;
        if (!isBotGame) currentScreen = 'lobby';
      });

      // ✅ If bot game — auto setup after room created
      if (isBotGame) {
        SocketService.instance.emit('pickTeam', {
          'room': code,
          'team': 'TEAM BLUE',
        });
        SocketService.instance.emit('addBots', {'room': code});
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          SocketService.instance.emit('startGame', {
            'room': code,
            'teamAName': 'TEAM BLUE',
            'teamBName': 'TEAM RED',
          });
        });
      }
    });

    socket.on('playerJoined', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ));
    });

    socket.on('currentPlayers', (data) {
      if (!mounted) return;
      setState(() {
        // ✅ Don't switch to lobby if it's a bot game — go straight to game
        if (!isBotGame) currentScreen = 'lobby';
        players = (data['players'] as List)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        hostName = data['hostName'];
        isHost = hostName == playerName;
        myTeam = players.firstWhere((p) => p['name'] == playerName,
            orElse: () => {})['team'];
      });
    });

    socket.on('initGame', (data) {
      if (!mounted) return;
      final safeData = Map<String, dynamic>.from(data);
      safeData['roomCode'] = roomCode;
      context.go('/game', extra: safeData);
    });

    socket.on('waitingReconnected', (data) {
      if (!mounted) return;
      setState(() {
        currentScreen = 'lobby';
        // ✅ FIX: Hydrate missing room code from server payload
        roomCode = data['roomCode'] ?? roomCode;
        players = (data['players'] as List)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        myTeam = data['myTeam'];
        hostName = data['hostName'];
        isHost = hostName == playerName;
        // Restore playerCount/teamSize from server on reconnect
        playerCount = (data['playerCount'] as num?)?.toInt() ?? 6;
        teamSize = (data['teamSize'] as num?)?.toInt() ?? 3;
      });
    });

    // roomFormat is emitted by the server immediately after createRoom
    // and joinRoom, telling us the game size for this room.
    // playerCount: 4 or 6  |  teamSize: 2 or 3
    socket.on('roomFormat', (data) {
      if (!mounted) return;
      setState(() {
        playerCount = (data['playerCount'] as num?)?.toInt() ?? 6;
        teamSize = (data['teamSize'] as num?)?.toInt() ?? 3;
      });
    });

    socket.on('reconnected', (data) {
      if (!mounted) return;

      // ✅ FIX: Ensure our local state has the roomCode before navigating
      setState(() {
        roomCode = data['roomCode'] ?? roomCode;
      });

      context.go('/game', extra: {
        'players': data['players'],
        'myHand': data['myHand'],
        'score': data['score'],
        'setsRemaining': data['setsRemaining'],
        'teamAName': data['teamAName'],
        'teamBName': data['teamBName'],
        'turnOrder': data['turnOrder'],
        'firstTurn': data['currentTurn'],
        'currentTurn': data['currentTurn'],
        // ✅ FIX: Pass the newly hydrated roomCode
        'roomCode': data['roomCode'] ?? roomCode,
      });
    });

    socket.on('connect_error', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Unable to connect to server. Check your internet connection.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ));
    });

    socket.on('disconnect', (_) {
      if (!mounted || currentScreen == 'home') return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connection lost. Reconnecting...',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ));
    });

    for (final event in [
      'createRoomError',
      'joinRoomError',
      'userNameExistError',
      'teamFull',
      'startGameError',
      'addBotsError',
    ]) {
      socket.on(event, (data) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            data['message'] ?? 'An error occurred.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ));
      });
    }
  }

  // ── HOST GAME — center dialog, name only ──────────────────────
  //
  //  showDialog() renders a card in the CENTER of the screen,
  //  unlike showModalBottomSheet which slides up from the bottom.
  //  _NameDialog handles the single-field layout.

  void _onHostGameTapped() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _NameDialog(
        title: 'Host a Game',
        subtitle: 'Choose your display name and game size',
        confirmLabel: 'Create Room',
        // onConfirmed now receives both name and the chosen player count
        onConfirmed: (name, count) {
          setState(() => playerName = name);
          // Pass playerCount to server — server accepts 4 or 6 (defaults to 6)
          SocketService.instance.emit('createRoom', {
            'name': name,
            'playerCount': count,
          });
        },
      ),
    );
  }

  // ── JOIN GAME — center dialog, room code + name ───────────────
  //
  //  _JoinDialog shows TWO labelled fields: room code + name.
  //  The confirm button only enables when both fields are filled.

  void _onJoinGameTapped() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _JoinDialog(
        onConfirmed: (code, name) {
          setState(() {
            playerName = name;
            roomCode = code;
          });
          SocketService.instance.saveSession(name, code);
          SocketService.instance.emit('joinRoom', {'name': name, 'room': code});
        },
      ),
    );
  }

  void _onPlayWithBotsTapped() {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _NameDialog(
      title: 'Play with Bots',
      subtitle: 'Choose your name and game size',
      confirmLabel: 'Start Game',
      onConfirmed: (name, count) {
        setState(() {
          playerName = name;
          isBotGame = true;
        });
        _startBotGame(name, count);
      },
    ),
  );
}

void _startBotGame(String name, int playerCount) {
  SocketService.instance.emit('createRoom', {
    'name': name,
    'playerCount': playerCount,
  });
}

  // ═══════════════════════════════════════════════════════════════
  //  HOME VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHomeView() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // ── Top breathing room ──────────────────────────────
                const Spacer(flex: 2),

                // ── Logo ────────────────────────────────────────────
                const _LogoBanner(),

                // ── Gap between logo and buttons ────────────────────
                // flex: 2 (down from 3) pulls the buttons closer to
                // the larger logo so they feel like one unit.
                const Spacer(flex: 2),

                // ── Buttons ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Expanded(child: _HostGameButton(onTap: _onHostGameTapped)),
                      const SizedBox(width: 12),
                      Expanded(child: _PlayWithBotsButton(onTap: _onPlayWithBotsTapped)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _JoinGameButton(onTap: _onJoinGameTapped),

                const Spacer(flex: 2),

                // ── How to play ─────────────────────────────────────
               _HowToPlayLink(
                  onTap: () => context.go('/onboarding'),
                ),

                // ── Fixed gap then footer links ──────────────────────
                const SizedBox(height: 20),

                _FooterLinks(
                  onFeedback: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                  onPrivacyPolicy: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
                  onAboutUs: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutUsScreen()),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Lobby view — unchanged, to be redesigned next ─────────────

  Widget _buildLobbyView() {
    final isLobbyFull =
        blueTeam.length == teamSize && redTeam.length == teamSize;

    // Players who have not yet picked a team — shown in waiting strip
    final waitingPlayers = players
        .where((p) => p['team'] == null)
        .map((p) => p['name'] as String)
        .toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: back button (left) + three-dot menu (right) ─
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _textSecondary, size: 20),
                    onPressed: () {
                      setState(() {
                        currentScreen = 'home';
                        playerName = '';
                        roomCode = '';
                        isHost = false;
                        players = [];
                        myTeam = null;
                        playerCount = 6;
                        teamSize = 3;
                      });
                      SocketService.instance.clearSession();
                      SocketService.instance.emit('leaveRoom', {});
                    },
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: _textSecondary, size: 22),
                    color: _surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'rules') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RulesScreen()));
                      } else if (value == 'feedback') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FeedbackScreen()));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rules',
                        child: Row(children: [
                          Icon(Icons.menu_book_rounded,
                              color: _textSecondary, size: 18),
                          SizedBox(width: 10),
                          Text('How to Play',
                              style:
                                  TextStyle(color: _textPrimary, fontSize: 14)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'feedback',
                        child: Row(children: [
                          Icon(Icons.feedback_outlined,
                              color: _textSecondary, size: 18),
                          SizedBox(width: 10),
                          Text('Feedback',
                              style:
                                  TextStyle(color: _textPrimary, fontSize: 14)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Room code ────────────────────────────────────────────
            const Text(
              'ROOM CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width:
                        48), // Offset for the share button to keep text centered
                Text(
                  roomCode,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: _peach,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    // Updated SharePlus syntax for v11.0.0+
                    await SharePlus.instance.share(
                      ShareParams(
                        text: 'Hey! Join my Literature game 🃏\n\nRoom Code: $roomCode\n\n👇 Tap to join:\nhttps://literatureserver-production.up.railway.app/join?room=$roomCode',
                        subject: 'Join Literature - Room $roomCode',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share, size: 24),
                  color: _peach.withValues(alpha: 0.8),
                  tooltip: 'Share Room Code',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Teams side by side (no JOIN chip — moved to bottom) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _LobbyTeamSection(
                          teamName: blueTeamName,
                          teamColor: const Color(0xFF6ECFCF),
                          filledNames: blueTeam,
                          teamSize: teamSize,
                          myName: playerName,
                          isHost: isHost,
                          onRemoveBot: (botName) => SocketService.instance
                              .emit('removeBot', {'room': roomCode, 'botName': botName}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _LobbyTeamSection(
                          teamName: redTeamName,
                          teamColor: _peach,
                          filledNames: redTeam,
                          teamSize: teamSize,
                          myName: playerName,
                          isHost: isHost,
                          onRemoveBot: (botName) => SocketService.instance
                              .emit('removeBot', {'room': roomCode, 'botName': botName}),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Waiting room strip ───────────────────────────────────
            // Shows players who have not yet joined any team.
            // Always visible; shows "Everyone has joined a team"
            // when waitingPlayers is empty.
            _LobbyWaitingStrip(waitingPlayers: waitingPlayers),

            // ── Bottom bar ───────────────────────────────────────────
            _LobbyBottomBar(
              playerName: playerName,
              myTeam: myTeam,
              isHost: isHost,
              isLobbyFull: isLobbyFull,
              hostName: hostName ?? '',
              blueTeamName: blueTeamName,
              redTeamName: redTeamName,
              blueTeamColor: const Color(0xFF6ECFCF),
              redTeamColor: _peach,
              blueTeamFull: blueTeam.length >= teamSize,
              redTeamFull: redTeam.length >= teamSize,
              onJoinBlue: () => SocketService.instance
                  .emit('pickTeam', {'room': roomCode, 'team': blueTeamName}),
              onJoinRed: () => SocketService.instance
                  .emit('pickTeam', {'room': roomCode, 'team': redTeamName}),
              onLeaveTeam: () => SocketService.instance
                  .emit('pickTeam', {'room': roomCode, 'team': null}),
              onStartGame: () => SocketService.instance.emit('startGame', {
                'room': roomCode,
                'teamAName': blueTeamName,
                'teamBName': redTeamName,
              }),
              onAddBots: () => SocketService.instance        // ← new
                  .emit('addBots', {'room': roomCode}),
              hasEmptySlots: !isLobbyFull, 
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentScreen == 'lobby') return _buildLobbyView();
    return _buildHomeView();
  }
}

// ═══════════════════════════════════════════════════════════════
//  LOBBY WIDGETS
// ═══════════════════════════════════════════════════════════════

// ── _LobbyTeamSection ─────────────────────────────────────────
//
//  Renders one complete team block:
//    • Header row — team name + "X / Y PLAYERS" count pill
//                   + "JOIN" chip (visible only when canJoin=true)
//    • List of filled player slots (one per player in team)
//    • List of empty "INVITE FRIEND" dashed slots for open spots
//
//  The caller passes canJoin so this widget never contains
//  socket logic — all socket calls stay in _PreGameScreensState.

class _LobbyTeamSection extends StatelessWidget {
  final String teamName;
  final Color teamColor;
  final List<String> filledNames;
  final int teamSize;
  final String myName;
  final bool isHost;                        // ← new
  final void Function(String)? onRemoveBot; // ← new

  const _LobbyTeamSection({
    required this.teamName,
    required this.teamColor,
    required this.filledNames,
    required this.teamSize,
    required this.myName,
    required this.isHost,                   // ← new
    this.onRemoveBot,                       // ← new
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header: team name + count pill ───────────────────
        Row(
          children: [
            Flexible(
              child: Text(
                teamName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: teamColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Text(
                '${filledNames.length}/$teamSize',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Filled player slots ──────────────────────────────
        ...filledNames.map((name) => _LobbyPlayerSlot(
              name: name,
              teamColor: teamColor,
              isMe: name == myName,
              isBot: name.startsWith('Bot '),
              isHost: isHost,
              onRemoveBot: name.startsWith('Bot ')
                  ? () => onRemoveBot?.call(name)
                  : null,
            )),

        // ── Empty slots — quiet placeholder boxes ────────────
        ...List.generate(
          teamSize - filledNames.length,
          (_) => Container(
            height: 60,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: teamColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── _LobbyPlayerSlot ──────────────────────────────────────────
//
//  A single filled player row. Three visual layers:
//    • A 4px left stripe in the team colour — the most distinctive
//      element from the mockup, giving each slot a colour-coded
//      identity at a glance.
//    • An avatar circle with the team colour as a ring border.
//    • Name (bold white) + "READY" status label (green).
//
//  If isMe=true, a small "(you)" tag is appended to the name and
//  the slot gets a very subtle tint so the player can spot
//  themselves instantly in a list.
//
//  "READY" is derived from the fact that the player is already
//  in a team — that's the only pre-game action required.

class _LobbyPlayerSlot extends StatelessWidget {
  final String name;
  final Color teamColor;
  final bool isMe;
  final bool isBot;                    // ← new
  final bool isHost;                   // ← new
  final VoidCallback? onRemoveBot;     // ← new

  const _LobbyPlayerSlot({
    required this.name,
    required this.teamColor,
    this.isMe = false,
    this.isBot = false,                // ← new
    this.isHost = false,               // ← new
    this.onRemoveBot,                  // ← new
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // isMe gets a subtle extra tint so the player stands out
        color: isMe ? teamColor.withValues(alpha: 0.10) : _elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? teamColor.withValues(alpha: 0.5) : _border,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Left colour stripe — 4px wide, left-side border radius
          Container(
            width: 4,
            height: 70,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar circle with team-coloured ring
          // Container(
          //   width: 44,
          //   height: 44,
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     color: _surface,
          //     border: Border.all(color: teamColor, width: 2),
          //   ),
          //   child: const Icon(Icons.person, color: Colors.white54, size: 24),
          // ),
          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Name row — name + optional "(you)" tag
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: teamColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'you',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: teamColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // "READY" label — green, small-caps style
                const Text(
                  'READY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),

          // Drag-handle dots (cosmetic — matches mockup)
          // Padding(
          //   padding: const EdgeInsets.only(right: 14),
          //   child: Column(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: List.generate(
          //         3,
          //         (_) => Container(
          //               margin: const EdgeInsets.symmetric(vertical: 2),
          //               child: Row(
          //                 mainAxisSize: MainAxisSize.min,
          //                 children: List.generate(
          //                     2,
          //                     (_) => Container(
          //                           width: 3,
          //                           height: 3,
          //                           margin: const EdgeInsets.symmetric(
          //                               horizontal: 1.5),
          //                           decoration: const BoxDecoration(
          //                             color: _textHint,
          //                             shape: BoxShape.circle,
          //                           ),
          //                         )),
          //               ),
          //             )),
          //   ),
          // ),
        ],
      ),
    );
  }
}

// ── _LobbyWaitingStrip ────────────────────────────────────────
//
//  A horizontal scrolling row of avatar chips for every player
//  who has not yet chosen a team. Sits between the team columns
//  and the bottom action bar.
//
//  When the list is empty every player is on a team and we show
//  a quiet "Everyone has joined a team" confirmation line.

class _LobbyWaitingStrip extends StatelessWidget {
  final List<String> waitingPlayers;

  const _LobbyWaitingStrip({required this.waitingPlayers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _border, width: 1),
          bottom: BorderSide(color: _border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Static label
          const Text(
            'WAITING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textHint,
            ),
          ),
          const SizedBox(width: 12),

          // Scrollable player chips or empty message
          Expanded(
            child: waitingPlayers.isEmpty
                ? const Text(
                    'Everyone has joined a team',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: _textHint,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: waitingPlayers.map((name) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _elevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: _textSecondary, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _LobbyBottomBar ───────────────────────────────────────────
//
//  Fixed container anchored at the screen bottom. Layout:
//
//  ┌──────────────────────────────────────┐
//  │        Playing as  <name>            │  ← centred label
//  │  [ Join Blue ]      [ Join Red  ]    │  ← team buttons
//  │         [ START GAME ]               │  ← host only
//  │   Waiting for <host> to start...     │  ← non-host only
//  └──────────────────────────────────────┘
//
//  Team button states (per team):
//    • Player has NOT chosen this team, team NOT full → active, team-coloured
//    • Player IS on this team                         → muted + "Leave" label
//    • Player is on the OTHER team, or team is full   → hidden
//
//  Start button states (host only):
//    • Teams not full → dark surface, "WAITING FOR PLAYERS..." text
//    • Teams full     → peach, "START GAME" text, tappable

class _LobbyBottomBar extends StatelessWidget {
  final String playerName;
  final String? myTeam;
  final bool isHost;
  final bool isLobbyFull;
  final String hostName;
  final String blueTeamName;
  final String redTeamName;
  final Color blueTeamColor;
  final Color redTeamColor;
  final bool blueTeamFull;
  final bool redTeamFull;
  final VoidCallback onJoinBlue;
  final VoidCallback onJoinRed;
  final VoidCallback onLeaveTeam;
  final VoidCallback onStartGame;
  final VoidCallback onAddBots;        // ← new
  final bool hasEmptySlots;            // ← new

  const _LobbyBottomBar({
    required this.playerName,
    required this.myTeam,
    required this.isHost,
    required this.isLobbyFull,
    required this.hostName,
    required this.blueTeamName,
    required this.redTeamName,
    required this.blueTeamColor,
    required this.redTeamColor,
    required this.blueTeamFull,
    required this.redTeamFull,
    required this.onJoinBlue,
    required this.onJoinRed,
    required this.onLeaveTeam,
    required this.onStartGame,
    required this.onAddBots,           // ← new
    required this.hasEmptySlots,       // ← new
  });

  @override
  Widget build(BuildContext context) {
    final onBlue = myTeam == blueTeamName; // am I on blue?
    final onRed = myTeam == redTeamName; // am I on red?

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── "Playing as" — centred ───────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Playing as  ',
                  style: TextStyle(color: _textHint, fontSize: 12),
                ),
                TextSpan(
                  text: playerName,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Team buttons ─────────────────────────────────────
          // Each button is only shown when relevant:
          //   • Join Blue: shown if player is not already on Red
          //   • Join Red:  shown if player is not already on Blue
          // When player is ON that team, the button shows "Leave"
          // in a muted style instead.
          Row(
            children: [
              // ── Blue button ─────────────────────────────────
              if (!onRed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _TeamButton(
                      label: onBlue ? 'Leave Blue' : 'Join Blue',
                      color: blueTeamColor,
                      isLeave: onBlue,
                      isDisabled: !onBlue && blueTeamFull,
                      onTap: onBlue ? onLeaveTeam : onJoinBlue,
                    ),
                  ),
                ),

              // ── Red button ──────────────────────────────────
              if (!onBlue)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _TeamButton(
                      label: onRed ? 'Leave Red' : 'Join Red',
                      color: redTeamColor,
                      isLeave: onRed,
                      isDisabled: !onRed && redTeamFull,
                      onTap: onRed ? onLeaveTeam : onJoinRed,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Add Bots button (host only) ───────────────────────
          if (isHost && hasEmptySlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onAddBots,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF6ECFCF),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: const Color(0xFF6ECFCF),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🤖', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Add remaining bots',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6ECFCF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Start / waiting row ───────────────────────────────
          if (isHost)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                // Button is always tappable when lobby is full;
                // when not full it is styled like a disabled state
                // but we intentionally don't pass null so the
                // text and style are controlled here not by Flutter.
                onPressed: isLobbyFull ? onStartGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLobbyFull ? _peach : _elevated,
                  disabledBackgroundColor: _elevated,
                  foregroundColor: const Color(0xFF3A1A00),
                  disabledForegroundColor: _textHint,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  isLobbyFull ? 'START GAME' : 'WAITING FOR PLAYERS...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isLobbyFull ? const Color(0xFF3A1A00) : _textHint,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                // hostName comes from the server's 'currentPlayers' payload
                'Waiting for $hostName to start the game...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _TeamButton ───────────────────────────────────────────────
//
//  A single team join/leave button used inside _LobbyBottomBar.
//
//  States:
//    isLeave=true  → muted border-only style, "Leave Blue/Red"
//    isDisabled    → greyed out, team is full
//    normal        → team-coloured filled button

class _TeamButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLeave;
  final bool isDisabled;
  final VoidCallback onTap;

  const _TeamButton({
    required this.label,
    required this.color,
    required this.isLeave,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Leave state: outlined, muted
    if (isLeave) {
      return SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: color.withValues(alpha: 0.08),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    // Disabled state: team is full
    if (isDisabled) {
      return SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _border, width: 1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledForegroundColor: _textHint,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textHint,
            ),
          ),
        ),
      );
    }

    // Normal state: filled, team-coloured
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF0C1A10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PRIVATE HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════

// ── Logo banner — layered version ─────────────────────────────
//
//  Three layers stacked on top of each other using a Stack:
//
//  Layer 1 (bottom): scattered card-suit symbols, very faint,
//            positioned manually to frame the logo.
//  Layer 2 (middle): a soft radial-gradient oval — like a
//            green spotlight glowing from behind the detective.
//            This gives the logo a sense of depth and lift.
//  Layer 3 (top):    the actual PNG logo image.
//
//  SETUP — copy the PNG and register in pubspec.yaml:
//    flutter:
//      assets:
//        - assets/images/Literature_logo_transparent.png

class _LogoBanner extends StatelessWidget {
  const _LogoBanner();

  @override
  Widget build(BuildContext context) {
    // 1.0 = full screen width. The transparent padding baked into
    // the PNG means the detective character fills the space without
    // clipping. No image re-export needed — Flutter scales at render.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoWidth = screenWidth > 500
        ? 400.0
        : screenWidth *
            0.85; // Keep height ratio at 0.55 — still proportional at full width.
    final double bannerHeight = logoWidth * 0.55;

    return SizedBox(
      width: logoWidth,
      height: bannerHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ..._buildSuitWatermarks(logoWidth, bannerHeight),

          // Glow oval scales with the new wider dimensions
          Center(
            child: Container(
              width: logoWidth * 0.88,
              height: bannerHeight * 0.80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x552A6A38),
                    Color(0x221A4A28),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          Image.asset(
            'assets/literature_logo_new.png',
            width: logoWidth,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported_rounded,
                    color: _textHint, size: 60),
                SizedBox(height: 8),
                Text(
                  'Add logo to assets/images/',
                  style: TextStyle(color: _textHint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSuitWatermarks(double bannerWidth, double bannerHeight) {
    const suits = [
      ('♦', 0.02, 0.05, 52.0),
      ('♣', 0.75, 0.08, 44.0),
      ('♠', 0.08, 0.62, 38.0),
      ('♥', 0.70, 0.58, 46.0),
      ('♦', 0.50, 0.00, 30.0),
    ];

    return suits.map(((String, double, double, double) s) {
      return Positioned(
        left: s.$2 * bannerWidth,
        top: s.$3 * bannerHeight,
        child: Text(
          s.$1,
          style: TextStyle(
            fontSize: s.$4,
            color: const Color(0x123A8A50),
          ),
        ),
      );
    }).toList();
  }
}

// ── Host Game button ───────────────────────────────────────────
//
//  Full-width with symmetric horizontal padding — chunky and boxy
//  rather than a narrow pill. BorderRadius of 16 gives rounded
//  corners without the fully-rounded stadium look.

class _HostGameButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HostGameButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = (screenWidth - 28 * 2 - 12) / 2;
    final double fontSize = (buttonWidth * 0.085).clamp(10.0, 15.0);
    final double iconSize = (buttonWidth * 0.11).clamp(14.0, 18.0);
    final double buttonHeight = (screenWidth * 0.15).clamp(52.0, 72.0);

    return SizedBox(
      height: buttonHeight,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _peach,
          foregroundColor: const Color(0xFF3A1A00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle, size: iconSize),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Host Game',
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayWithBotsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayWithBotsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = (screenWidth - 28 * 2 - 12) / 2;
    final double fontSize = (buttonWidth * 0.085).clamp(10.0, 15.0);
    final double iconSize = (buttonWidth * 0.11).clamp(14.0, 18.0);
    final double buttonHeight = (screenWidth * 0.15).clamp(52.0, 72.0);

    return SizedBox(
      height: buttonHeight,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _peach,
          foregroundColor: const Color(0xFF3A1A00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: iconSize),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Play with Bots',
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinGameButton extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinGameButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = screenWidth - 28 * 2;
    final double fontSize = (buttonWidth * 0.055).clamp(14.0, 17.0);
    final double iconSize = (buttonWidth * 0.065).clamp(18.0, 22.0);
    final double buttonHeight = (screenWidth * 0.17).clamp(56.0, 72.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7FD8C8),
            foregroundColor: const Color(0xFF0C2A22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_add_rounded, size: iconSize),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Join Game',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── How to play link ───────────────────────────────────────────
//
//  Simple tappable row with the book icon + "How to play?" text.
//  Lives near the bottom quarter of the screen — the Spacer()
//  layout above pushes it there without needing a fixed offset.

class _HowToPlayLink extends StatelessWidget {
  final VoidCallback onTap;
  const _HowToPlayLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _border, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: _textSecondary, size: 20),
            SizedBox(width: 10),
            Text(
              'How to play?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer links ───────────────────────────────────────────────
//
//  Three plain text links in a single row, separated by a small
//  raised dot (·) as a visual divider.  They intentionally have
//  no background or border — they should feel like fine print,
//  not buttons competing with the main CTAs above.
//
//  Each link uses an InkWell (instead of GestureDetector) so the
//  user gets a subtle ripple feedback on tap — a nice touch for
//  text-only interactive elements.

class _FooterLinks extends StatelessWidget {
  final VoidCallback onFeedback;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onAboutUs;

  const _FooterLinks({
    required this.onFeedback,
    required this.onPrivacyPolicy,
    required this.onAboutUs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _link('Feedback', onFeedback),
        _dot(),
        _link('Privacy Policy', onPrivacyPolicy),
        _dot(),
        _link('About Us', onAboutUs),
      ],
    );
  }

  // A single tappable text link
  Widget _link(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        // Extra padding enlarges the tap target without affecting
        // the visual size of the text
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _textHint,
            // Underline makes it obvious these are clickable links
            decoration: TextDecoration.underline,
            decorationColor: _textHint,
            decorationThickness: 0.8,
          ),
        ),
      ),
    );
  }

  // The · separator between links
  Widget _dot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          color: _textHint,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DIALOGS — render at screen center via showDialog()
// ═══════════════════════════════════════════════════════════════

// ── Shared dialog shell ────────────────────────────────────────
//
//  Wraps every dialog in a dark rounded card with a peach border.
//  Using Dialog() instead of AlertDialog() lets us control
//  every pixel of the layout.

class _DialogShell extends StatelessWidget {
  final Widget child;
  const _DialogShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _peach.withValues(alpha: 0.4), width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

// ── Reusable text field for inside dialogs ─────────────────────

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final VoidCallback? onSubmit;

  const _DialogTextField({
    required this.controller,
    required this.hintText,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.words,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _textHint),
        filled: true,
        fillColor: _elevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
    );
  }
}

// ── _NameDialog — used by Host Game ───────────────────────────
//
//  Contains:
//    1. A text field for the player's display name
//    2. A two-option toggle to pick 4-player or 6-player game
//
//  onConfirmed now passes BOTH the name AND the chosen player count
//  back to _onHostGameTapped, which includes it in the socket emit.

class _NameDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  // Updated signature: receives name AND playerCount (4 or 6)
  final void Function(String name, int playerCount) onConfirmed;

  const _NameDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _nameCtrl = TextEditingController();

  // Default to 6-player — matches the server's own default
  int _selectedCount = 6;

  bool get _canConfirm => _nameCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.pop(context);
    widget.onConfirmed(_nameCtrl.text.trim(), _selectedCount);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title + subtitle ───────────────────────────────
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          Text(widget.subtitle,
              style: const TextStyle(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 20),

          // ── Name field ────────────────────────────────────
          _DialogTextField(
            controller: _nameCtrl,
            hintText: 'Your name...',
            autofocus: true,
            onSubmit: _confirm,
          ),
          const SizedBox(height: 20),

          // ── Player count toggle ───────────────────────────
          //
          //  Two tappable tiles side by side.
          //  The selected one gets a peach border + peach text.
          //  The unselected one stays muted.
          //
          //  "GAME SIZE" small-caps label sits above the tiles
          //  so the user knows what they're choosing.
          const Text(
            'GAME SIZE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PlayerCountTile(
                  count: 4,
                  label: '4 Players',
                  sublabel: '2 vs 2',
                  isSelected: _selectedCount == 4,
                  onTap: () => setState(() => _selectedCount = 4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PlayerCountTile(
                  count: 6,
                  label: '6 Players',
                  sublabel: '3 vs 3',
                  isSelected: _selectedCount == 6,
                  onTap: () => setState(() => _selectedCount = 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Confirm button ────────────────────────────────
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _peach,
                disabledBackgroundColor: _elevated,
                foregroundColor: const Color(0xFF3A1A00),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(widget.confirmLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player count tile ──────────────────────────────────────────
//
//  One of the two selectable tiles inside _NameDialog.
//  Shows the player count as a large number, a label below it,
//  and a "2 vs 2" / "3 vs 3" sublabel beneath that.
//
//  Selected state: peach border + peach count number
//  Unselected state: muted border + muted text

class _PlayerCountTile extends StatelessWidget {
  final int count;
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerCountTile({
    required this.count,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colours swap between selected and unselected states
    final borderColor = isSelected ? _peach : _border;
    final countColor = isSelected ? _peach : _textHint;
    final labelColor = isSelected ? _textPrimary : _textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // AnimatedContainer smoothly animates the border colour change
        // when the player taps between the two tiles
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _peach.withValues(alpha: 0.08) // very subtle tint
              : _elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large count number
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: countColor,
              ),
            ),
            const SizedBox(height: 2),
            // "4 Players" / "6 Players"
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 2),
            // "2 vs 2" / "3 vs 3"
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _JoinDialog — used by Join Game ───────────────────────────
//
//  Two labelled fields: ROOM CODE (all-caps) + YOUR NAME.
//  The teal "Enter Lobby" button enables only when both are filled.

class _JoinDialog extends StatefulWidget {
  final void Function(String code, String name) onConfirmed;
  final String? initialRoomCode;

  const _JoinDialog({
    required this.onConfirmed,
    this.initialRoomCode,
  });

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool get _canConfirm =>
      _codeCtrl.text.trim().isNotEmpty && _nameCtrl.text.trim().isNotEmpty;

  @override
    void initState() {
      super.initState();
      if (widget.initialRoomCode != null) {
        _codeCtrl.text = widget.initialRoomCode!;
      }
      _codeCtrl.addListener(() => setState(() {}));
      _nameCtrl.addListener(() => setState(() {}));
    }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.pop(context);
    widget.onConfirmed(
      _codeCtrl.text.trim().toUpperCase(),
      _nameCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Join a Game',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Enter the room code and your display name',
              style: TextStyle(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 20),

          // Room code field
          const Text('ROOM CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: _textSecondary,
              )),
          const SizedBox(height: 8),
          _DialogTextField(
            controller: _codeCtrl,
            hintText: 'E.G., L1T3',
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),

          // Name field
          const Text('YOUR NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: _textSecondary,
              )),
          const SizedBox(height: 8),
          _DialogTextField(
            controller: _nameCtrl,
            hintText: 'Your name...',
            onSubmit: _confirm,
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FD8C8),
                disabledBackgroundColor: _elevated,
                foregroundColor: const Color(0xFF0C2A22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Enter Lobby',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _HostOnlyBadge ────────────────────────────────────────────
// ignore: unused_element
class _HostOnlyBadge extends StatelessWidget {
  const _HostOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6ECFCF).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF6ECFCF).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Text(
        'HOST ONLY',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6ECFCF),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
