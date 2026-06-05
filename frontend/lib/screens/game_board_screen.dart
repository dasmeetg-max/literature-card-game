// ---------------------------------------------------
// lib/screens/game_board_screen.dart
// ---------------------------------------------------
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/socket_service.dart';
import '../widgets/unified_scoreboard.dart';
import '../widgets/player_avatar.dart';
import '../widgets/fanned_hand.dart';
import '../widgets/action_buttons.dart';
import '../widgets/table_event_splash.dart';
import '../screens/feedback_screen.dart';
import '../screens/rules_screen.dart';
import '../services/wakelock_service.dart';
import 'package:flutter/services.dart';

class GameBoardScreen extends StatefulWidget {
  final Map<String, dynamic> initialGameData;
  const GameBoardScreen({super.key, required this.initialGameData});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen>
    with WidgetsBindingObserver {
  late Map<String, dynamic> gameData;
  String? myName;
  String? myId;

  String _currentEvent = 'none';
  String _eventSubtitle = '';
  Map<String, dynamic>? _currentCard;
  List<Map<String, dynamic>>? _currentSet;

  bool _isPaused = false;
  String _pausedPlayerName = '';

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    WakelockService.enable();
    debugPrint(
        '🎲 [GAME-BOARD] initState started. Parsing initial game data...');
    gameData = Map<String, dynamic>.from(widget.initialGameData);
    gameData['currentTurn'] = gameData['firstTurn'];
    final socket = SocketService.instance.socket;
    myId = socket.id;

    if (gameData['players'] != null) {
      List<Map<String, dynamic>> parsedPlayers = [];
      for (var rawPlayer in gameData['players']) {
        Map<String, dynamic> p = Map<String, dynamic>.from(rawPlayer);
        p['cardCount'] = p['cardCount'] ?? 0;
        parsedPlayers.add(p);
        if (p['id'] == myId) {
          myName = p['name'];
          gameData['myTeam'] = p['team'];
        }
      }
      gameData['players'] = parsedPlayers;
    }
    debugPrint('👤 [GAME-BOARD] My identity confirmed: ID=$myId, Name=$myName');
    _setupSocketListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          '🔄 [GAME-BOARD] App resumed. Trusting SocketService to manage connection.');
    }
  }

  @override
  void dispose() {
    final socket = SocketService.instance.socket;
    WidgetsBinding.instance.removeObserver(this);
    socket.off('yourHand');
    socket.off('turnChanged');
    socket.off('cardRequested');
    socket.off('cardResponseResult');
    socket.off('cardTransferAnnounced');
    socket.off('invalidAsk');
    socket.off('declareSetResult');
    socket.off('gameOver');
    socket.off('playerDisconnected');
    socket.off('playerReconnected');
    socket.off('gameResumed');
    socket.off('gamePaused');
    socket.off('reconnected');
    WakelockService.disable();
    super.dispose();
  }

Timer? _eventClearTimer;

void _showEvent(
  String eventType,
  String subtitle, {
  Map<String, dynamic>? card,
  List<Map<String, dynamic>>? set,
}) {
  _eventClearTimer?.cancel();

  // ✅ If something already showing — brief blank then show new
  if (_currentEvent != 'none') {
    setState(() {
      _currentEvent = 'none';
      _eventSubtitle = '';
      _currentCard = null;
      _currentSet = null;
    });

    _eventClearTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _currentEvent = eventType;
        _eventSubtitle = subtitle;
        _currentCard = card;
        _currentSet = set;
      });
    });
  } else {
    // ✅ Nothing showing — display immediately
    setState(() {
      _currentEvent = eventType;
      _eventSubtitle = subtitle;
      _currentCard = card;
      _currentSet = set;
    });
  }
}

  void _syncFullState(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      if (data['roomCode'] != null) gameData['roomCode'] = data['roomCode'];
      if (data['players'] != null) {
        gameData['players'] = (data['players'] as List)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      }
      if (data['myHand'] != null) {
        gameData['myHand'] = (data['myHand'] as List)
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
      }
      if (data['score'] != null) {
        gameData['score'] = Map<String, dynamic>.from(data['score']);
      }
      if (data['setsRemaining'] != null) {
        gameData['setsRemaining'] = data['setsRemaining'];
      }
      if (data['teamAName'] != null) gameData['teamAName'] = data['teamAName'];
      if (data['teamBName'] != null) gameData['teamBName'] = data['teamBName'];
      if (data['turnOrder'] != null) {
        gameData['turnOrder'] = (data['turnOrder'] as List)
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      }
      if (data['currentTurn'] != null) {
        gameData['currentTurn'] = data['currentTurn'];
      }
      if (data['hostName'] != null) gameData['hostName'] = data['hostName'];

      myId = SocketService.instance.socket.id;
      if (gameData['players'] != null) {
        final me = (gameData['players'] as List).firstWhere(
          (p) => p['name'] == myName,
          orElse: () => null,
        );
        if (me != null) {
          myId = me['id'];
          gameData['myTeam'] = me['team'];
        }
      }
      _isPaused = false;
      _pausedPlayerName = '';
    });
    debugPrint('🔄 [GAME-BOARD] Full state synchronized from server.');
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance;

    socket.on('reconnected', (data) {
      _syncFullState(Map<String, dynamic>.from(data));
    });

    socket.on('yourHand', (data) {
      if (mounted) {
        setState(() {
          gameData['myHand'] = List<Map<String, dynamic>>.from(data['hand']);
        });
      }
    });

    socket.on('turnChanged', (data) {
      if (!mounted) return;
      debugPrint('🔄 [GAME-BOARD] Turn changed to: ${data['playerName']}');
      if (data['playerName'] == myName) HapticFeedback.mediumImpact();
      setState(() {
        gameData['currentTurn'] = data['playerName'];
        final rawCounts = data['cardCounts'];
        if (rawCounts != null) {
          final cardCounts = rawCounts as List;
          for (var p in gameData['players']) {
            final update = cardCounts.firstWhere(
              (c) => c['id'] == p['id'],
              orElse: () => null,
            );
            if (update != null) p['cardCount'] = update['cardCount'];
          }
        }
      });
    });

    socket.on('cardRequested', (data) {
      if (!mounted) return;
      debugPrint('📥 [GAME-BOARD] Someone asked me for a card: $data');
      SocketService.instance.emit('cardResponse', {
        'room': gameData['roomCode'],
        'toId': data['fromId'],
        'card': data['card'],
      });
    });

    socket.on('cardResponseResult', (data) {
      if (!mounted) return;
      debugPrint('📥 [GAME-BOARD] Result of my ask: $data');
      if (data['hasCard'] == true) {
        HapticFeedback.mediumImpact();
        setState(() {
          List<Map<String, dynamic>> myHand =
              List<Map<String, dynamic>>.from(gameData['myHand'] ?? []);
          myHand.add(Map<String, dynamic>.from(data['card']));
          gameData['myHand'] = myHand;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              children: [
                const TextSpan(text: "✅ You got the "),
                TextSpan(text: "${data['card']['rank']}"),
                TextSpan(
                  text: "${data['card']['suit']}",
                  style: TextStyle(
                    color: (data['card']['suit'] == '♥' ||
                            data['card']['suit'] == '♦')
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                const TextSpan(text: "!"),
              ],
            ),
          ),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ ${data['fromName']} didn't have it."),
          backgroundColor: Colors.redAccent,
        ));
      }
    });

    socket.on('cardTransferAnnounced', (data) {
      if (!mounted) return;
      debugPrint('📢 [GAME-BOARD] Card transfer announced: $data');
      String dynamicSubtitle = "";
      final card = data['card'];
      final cardStr = "${card['rank']}${card['suit']}";

      if (data['hasCard'] == true) {
        if (data['toName'] == myName) {
          dynamicSubtitle = "You stole from ${data['fromName']}";
        } else if (data['fromName'] == myName) {
          dynamicSubtitle = "${data['toName']} stole from you";
        } else {
          dynamicSubtitle = "${data['toName']} stole from ${data['fromName']}";
        }
        _showEvent('ask_success', dynamicSubtitle,
            card: Map<String, dynamic>.from(data['card']));
      } else {
        if (data['toName'] == myName) {
          dynamicSubtitle = "You asked ${data['fromName']} for $cardStr";
        } else if (data['fromName'] == myName) {
          dynamicSubtitle = "${data['toName']} asked you for $cardStr";
        } else {
          dynamicSubtitle =
              "${data['toName']} asked ${data['fromName']} for $cardStr";
        }
        _showEvent('ask_fail', dynamicSubtitle,
            card: Map<String, dynamic>.from(data['card']));
      }

      if (data['hasCard'] == true && data['fromName'] == myName) {
        HapticFeedback.heavyImpact();
        setState(() {
          List<Map<String, dynamic>> myHand =
              List<Map<String, dynamic>>.from(gameData['myHand'] ?? []);
          myHand.removeWhere(
            (c) =>
                c['suit'] == data['card']['suit'] &&
                c['rank'] == data['card']['rank'],
          );
          gameData['myHand'] = myHand;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              children: [
                TextSpan(text: "⚠️ ${data['toName']} stole your "),
                TextSpan(text: "${data['card']['rank']}"),
                TextSpan(
                  text: "${data['card']['suit']}",
                  style: TextStyle(
                    color: (data['card']['suit'] == '♥' ||
                            data['card']['suit'] == '♦')
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                const TextSpan(text: "!"),
              ],
            ),
          ),
          backgroundColor: Colors.orange[800],
        ));
      }
    });

    socket.on('invalidAsk', (data) {
      if (!mounted) return;
      debugPrint('❌ [GAME-BOARD] Invalid Ask: $data');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message'] ?? 'Invalid move'),
        backgroundColor: Colors.red,
      ));
    });

    socket.on('playerDisconnected', (data) {
      if (!mounted) return;
      final playerName = data['playerName'] ?? 'A player';
      final paused = data['paused'] == true;
      if (paused) {
        setState(() {
          _isPaused = true;
          _pausedPlayerName = playerName;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("⚠️ $playerName disconnected — waiting to reconnect..."),
        backgroundColor: Colors.orange[800],
        duration: const Duration(seconds: 5),
      ));
    });

    socket.on('gamePaused', (data) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isPaused = true;
      });
    });

    socket.on('playerReconnected', (data) {
      if (!mounted) return;
      final playerName = data['playerName'] ?? 'A player';
      final newPlayerId = data['newPlayerId'] as String?;
      if (newPlayerId != null) {
        setState(() {
          final players = gameData['players'] as List?;
          if (players != null) {
            for (final p in players) {
              if (p['name'] == playerName) {
                p['id'] = newPlayerId;
                break;
              }
            }
          }
          final turnOrder = gameData['turnOrder'] as List?;
          if (turnOrder != null) {
            for (final p in turnOrder) {
              if (p['name'] == playerName) {
                p['id'] = newPlayerId;
                break;
              }
            }
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ $playerName reconnected — game resuming!",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
      ));
    });

    socket.on('gameResumed', (data) {
      if (!mounted) return;
      final reason = data['reason'] ?? 'Game is resuming';
      HapticFeedback.mediumImpact();
      setState(() {
        _isPaused = false;
        _pausedPlayerName = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("▶️ $reason"),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
      ));
    });

    socket.on('declareSetResult', (data) {
      if (!mounted) return;
      try {
        debugPrint('📢 [GAME-BOARD] Declare Set Result Payload: $data');
        final declaredSet = data['set'] != null
            ? (data['set'] as List)
                .map((c) => Map<String, dynamic>.from(c))
                .toList()
            : null;

        bool isMyTeam = (data['team'] == gameData['myTeam']);
        bool isMe = (data['playerName'] == myName);
        String dynamicSubtitle = "";

        if (data['declaringTeamWon'] == true) {
          if (isMe) {
            dynamicSubtitle = "You scored for your team!";
          } else if (isMyTeam) {
            dynamicSubtitle = "${data['playerName']} scored for your team!";
          } else {
            dynamicSubtitle = "${data['playerName']}'s team scores";
          }
          if (isMyTeam) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 300),
                () => HapticFeedback.heavyImpact());
          } else {
            HapticFeedback.mediumImpact();
          }
          _showEvent('declare_success', dynamicSubtitle, set: declaredSet);
        } else if (data['opponentTeamWon'] == true) {
          if (isMyTeam) {
            dynamicSubtitle = isMe
                ? "Opponent held a card — Your team loses the point"
                : "${data['playerName']}'s declaration failed — Point lost";
            HapticFeedback.heavyImpact();
          } else {
            dynamicSubtitle =
                "Opponent's declaration failed — Your team scores!";
            HapticFeedback.mediumImpact();
          }
          _showEvent('declare_fail', dynamicSubtitle, set: declaredSet);
        } else if (data['mappingFailed'] == true) {
          if (isMyTeam) {
            dynamicSubtitle = isMe
                ? "You assigned cards incorrectly — Point lost"
                : "${data['playerName']} assigned cards incorrectly — Point lost";
            HapticFeedback.heavyImpact();
          } else {
            dynamicSubtitle = "Opponent mapped incorrectly — Your team scores!";
            HapticFeedback.mediumImpact();
          }
          _showEvent('mapping_failed', dynamicSubtitle, set: declaredSet);
        }

        String message = "";
        Color bannerColor = Colors.grey;
        if (data['declaringTeamWon'] == true) {
          message = "🏆 ${data['playerName']} successfully mapped the set!";
          bannerColor = Colors.green;
        } else if (data['opponentTeamWon'] == true) {
          message =
              "⚡ ${data['playerName']} declared, but the opponent had a card!";
          bannerColor = Colors.orange[800]!;
        } else if (data['mappingFailed'] == true) {
          message =
              "❌ ${data['playerName']} guessed the wrong players! Point lost.";
          bannerColor = Colors.redAccent;
        }

        if (message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            backgroundColor: bannerColor,
            duration: const Duration(seconds: 4),
          ));
        }

        setState(() {
          if (data['score'] != null) {
            gameData['score'] = Map<String, dynamic>.from(data['score']);
          }
          gameData['setsRemaining'] = data['setsRemaining'];
          gameData['nextTurn'] = data['nextTurn'];
          gameData['currentTurn'] = data['nextTurn'];

          if (data['cardCounts'] != null) {
            final cardCounts = data['cardCounts'] as List;
            for (var p in gameData['players']) {
              for (var c in cardCounts) {
                if (c['id'] == p['id']) {
                  p['cardCount'] = c['cardCount'];
                  break;
                }
              }
            }
          }

          if (data['updatedHands'] != null) {
            final updatedHands = data['updatedHands'] as List;
            for (var p in gameData['players']) {
              for (var h in updatedHands) {
                if (h['id'] == p['id']) {
                  p['hand'] = (h['hand'] as List)
                      .map((card) => Map<String, dynamic>.from(card))
                      .toList();
                  break;
                }
              }
            }
            for (var h in updatedHands) {
              if (h['id'] == myId) {
                gameData['myHand'] = (h['hand'] as List)
                    .map((card) => Map<String, dynamic>.from(card))
                    .toList();
                break;
              }
            }
          }
        });
      } catch (e, stacktrace) {
        debugPrint('❌ [GAME-BOARD] Crash inside declareSetResult: $e');
        debugPrint(stacktrace.toString());
      }
    });

    socket.on('gameOver', (data) {
      if (!mounted) return;
      context.go('/game-over', extra: {
        'scoreA': data['score']['teamA'],
        'scoreB': data['score']['teamB'],
        'winner': data['winner'],
        'isDraw': data['draw'],
        'teamAName': gameData['teamAName'],
        'teamBName': gameData['teamBName'],
        'roomCode': gameData['roomCode'],
        'playerCount': (gameData['players'] as List).length,
        'playerName': myName,
        'isHost': gameData['hostName'] == myName,
      });
    });
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_filled,
                    color: Colors.orange, size: 56),
                const SizedBox(height: 16),
                const Text("GAME PAUSED",
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3)),
                const SizedBox(height: 12),
                Text(
                  _pausedPlayerName.isNotEmpty
                      ? "Waiting for $_pausedPlayerName to reconnect..."
                      : "Waiting for a player to reconnect...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        color: Colors.orange, strokeWidth: 3)),
                const SizedBox(height: 20),
                const Text('Share this room code to reconnect:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameData['roomCode'] ?? '',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: Colors.white54, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: gameData['roomCode'] ?? ''));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Room code copied!',
                              style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stadium Avatar Geometry
  //
  // Anchors avatars to geometric points around a stadium shape.
  // Returns Offsets representing the AVATAR CENTER relative to the TABLE CENTER.
  // ─────────────────────────────────────────────────────────────────────────
  List<Offset> _getStadiumAvatarOffsets(
      int count, double tableW, double tableH, double gapToCenter) {
    if (count == 0) return [];

    final double r = tableW / 2;
    // Length of the straight vertical edge (from center)
    final double straightY = max(0.0, (tableH - tableW) / 2);

    // Helper: Gets exact X/Y based on distance from the stadium edge
    Offset getSideOffset(double targetY, double side) {
      if (targetY.abs() <= straightY) {
        // We are within the straight edge bounds
        return Offset(side * (r + gapToCenter), targetY);
      } else {
        // We are wrapping around the top/bottom semicircles
        double cy = targetY > 0 ? straightY : -straightY;
        double localY = targetY - cy;
        double hypotenuse = r + gapToCenter;
        // Clamp to prevent NaN if math gets pushed too far vertically
        double localYClamped = localY.clamp(-hypotenuse, hypotenuse);
        double localX =
            sqrt(hypotenuse * hypotenuse - localYClamped * localYClamped);
        return Offset(side * localX, targetY);
      }
    }

    List<Offset> offsets = [];
    if (count <= 3) {
      // 4-player layout (3 Opponents): Left, Top, Right
      if (count > 0) offsets.add(getSideOffset(0, -1)); // Left Edge Midpoint
      if (count > 1) {
        offsets.add(Offset(0, -tableH / 2 - gapToCenter)); // Top Center
      }
      if (count > 2) offsets.add(getSideOffset(0, 1)); // Right Edge Midpoint
    } else {
      // 6-player layout (5 Opponents): Bottom-Left, Top-Left, Top, Top-Right, Bottom-Right
      const double vSpacing =
          130.0; // Guaranteed vertical separation between side pairs
      if (count > 0) {
        offsets.add(getSideOffset(vSpacing / 2, -1)); // Bottom-Left
      }
      if (count > 1) offsets.add(getSideOffset(-vSpacing / 2, -1)); // Top-Left
      if (count > 2) {
        offsets.add(Offset(0, -tableH / 2 - gapToCenter)); // Top Center
      }
      if (count > 3) offsets.add(getSideOffset(-vSpacing / 2, 1)); // Top-Right
      if (count > 4) {
        offsets.add(getSideOffset(vSpacing / 2, 1)); // Bottom-Right
      }
    }
    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    if (gameData.isEmpty) {
      return const Scaffold(body: Center(child: Text("Error: No game data")));
    }

    final players = gameData['players'] as List;
    final turnOrder = gameData['turnOrder'] as List;

    List<Map<String, dynamic>> arrangedPlayers = [];
    if (myId != null) {
      final myIndex = turnOrder.indexWhere((p) => p['id'] == myId);
      if (myIndex != -1) {
        for (int i = 0; i < turnOrder.length; i++) {
          var rawTurnPlayer = turnOrder[(myIndex + i) % turnOrder.length];
          Map<String, dynamic> turnPlayer =
              Map<String, dynamic>.from(rawTurnPlayer);
          if (turnPlayer['id'] == myId) continue;
          var fullPlayer = players.firstWhere(
            (p) => p['id'] == turnPlayer['id'],
            orElse: () => turnPlayer,
          );
          arrangedPlayers.add(Map<String, dynamic>.from(fullPlayer));
        }
      } else {
        arrangedPlayers = List<Map<String, dynamic>>.from(
          players.where((p) => p['id'] != myId),
        );
      }
    } else {
      arrangedPlayers = List<Map<String, dynamic>>.from(players);
    }

    final scoreA = gameData['score']['teamA'];
    final scoreB = gameData['score']['teamB'];
    final teamAName = gameData['teamAName'];
    final teamBName = gameData['teamBName'];

// ── 1. Responsive & Constrained Dimensions ─────────────────────────────
    final int opponentCount = arrangedPlayers.length;
    final Size screenSize = MediaQuery.of(context).size;

    // THE LETTERBOX CONSTRAINT: Dynamic Aspect Ratio Anchoring (9:16 approx)
    final double screenHeight = screenSize.height;
    // Calculate the ideal mobile width based on how tall the screen is
    final double idealMobileWidth = screenHeight * 0.5625; // 9/16 aspect ratio

    // Safety clamps: Ensure the letterbox never gets absurdly thin or excessively wide
    final double maxAppWidth = idealMobileWidth.clamp(350.0, 600.0);

    // The active width is the smaller of the actual screen width or our clamped ideal width
    final double activeWidth = min(screenSize.width, maxAppWidth);

    // Fixed clearances to establish the safe bounding box
    const double topChrome = 100.0;
    const double bottomChrome = 190.0;
    final double availableH = screenHeight - topChrome - bottomChrome;

    // Avatar dimensional estimations (Used for calculating safe edges)
    const double avatarHalfW = 40.0;
    const double avatarHalfH = 45.0;
    const double avatarCenterGap =
        50.0; // Distance from Table Edge to Avatar Center

    // Max bounds derived by working backward from available space
    final double maxTableW = activeWidth - 2 * (avatarCenterGap + avatarHalfW);
    // Allow clearance for the Top Avatar and Bottom side avatars
    final double maxTableH = availableH - 2 * (avatarCenterGap + avatarHalfH);

    // Dynamic Aspect Ratio: Elongate the table to fill the new vertical space
    final double desiredRatio = opponentCount > 3 ? 1.55 : 1.45;

    // Max-Fill Math
    double tableWidth = maxTableW;
    double tableHeight = tableWidth * desiredRatio;

    // Scale down gracefully if hitting the vertical limit
    if (tableHeight > maxTableH) {
      tableHeight = maxTableH;
      tableWidth = tableHeight / desiredRatio;
    }

    // Absolute minimum failsafe
    if (tableWidth < 160.0) {
      tableWidth = 160.0;
      tableHeight = max(tableWidth, tableHeight);
    }

    // Generate the exact geometric anchor points for the opponents
    final List<Offset> offsets = _getStadiumAvatarOffsets(
      opponentCount,
      tableWidth,
      tableHeight,
      avatarCenterGap,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0C1A10),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. INFINITE BACKGROUND (Bleeds out on widescreen devices)
            Container(
              color: const Color(0xFF0C1A10),
              width: double.infinity,
              height: double.infinity,
            ),

            // 2. CONSTRAINED GAMEPLAY VIEWPORT (Centers like a phone screen)
            Center(
              child: SizedBox(
                width: activeWidth, // The strict horizontal clamp
                height: screenHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // --- TOP CHROME ---
                    Positioned(
                      top: 16, // Pushed right up to the top center safe area
                      left: 0,
                      right: 0,
                      child: Center(
                        child: UnifiedScoreboard(
                          teamAName: teamAName ?? 'TEAM A',
                          scoreA: scoreA ?? 0,
                          teamAColor: const Color(0xFF6ECFCF), // Existing Blue
                          teamBName: teamBName ?? 'TEAM B',
                          scoreB: scoreB ?? 0,
                          teamBColor:
                              const Color(0xFFF4A76F), // Existing Peach/Red
                          roomCode: gameData['roomCode'] ?? '',
                        ),
                      ),
                    ),

                 Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Color(0xFF8AAF90), size: 22),
                            color: const Color(0xFF15281A),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'feedback') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const FeedbackScreen()));
                              } else if (value == 'exit') {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF15281A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                          color: Color(0xFF2A7A3E), width: 1.5),
                                    ),
                                    title: const Text(
                                      'Exit Game?',
                                      style: TextStyle(
                                        color: Color(0xFF8AAF90),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to leave?',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                SocketService.instance.clearSession();
                                                SocketService.instance.emit('leaveRoom', {});
                                                Navigator.pop(context);
                                                context.go('/');
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red[700],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 14),
                                              ),
                                              child: const Text(
                                                'Exit',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFF4A76F),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 14),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                    color: Colors.black87,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'feedback',
                                child: Row(children: [
                                  Icon(Icons.feedback_outlined,
                                      color: Color(0xFF8AAF90), size: 18),
                                  SizedBox(width: 10),
                                  Text('Feedback',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'exit',
                                child: Row(children: [
                                  Icon(Icons.exit_to_app,
                                      color: Colors.redAccent, size: 18),
                                  SizedBox(width: 10),
                                  Text('Exit Game',
                                      style: TextStyle(
                                          color: Colors.redAccent, fontSize: 14)),
                                ]),
                              ),
                            ],
                          ),
                          // ✅ Question mark below 3 dots → opens RulesScreen
                          IconButton(
                            icon: const Icon(Icons.help_outline_rounded,
                                color: Color(0xFF8AAF90), size: 22),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RulesScreen()),
                            ),
                            tooltip: 'How to play',
                          ),
                        ],
                      ),
                    ),
                    // --- THE GAME BOARD (Table + Avatars) ---
                    // Dedicated stack that fills the central vertical space
                    Positioned(
                      top: topChrome,
                      left: 0,
                      right: 0,
                      height: availableH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ── Centered Stadium Table ──
                          Center(
                            child: Container(
                              width: tableWidth,
                              height: tableHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A5C2E),
                                borderRadius:
                                    BorderRadius.circular(tableWidth / 2),
                                border: Border.all(
                                  color: const Color(0xFF2A7A3E),
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF0A3A18),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Padding(
                                // Fixed padding prevents squishing on small screens
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 24.0,
                                ),
                                child: Center(
                                  child: TableEventSplash(
                                    eventType: _currentEvent,
                                    subtitle: _eventSubtitle,
                                    card: _currentCard,
                                    set: _currentSet,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Precision Avatar Placements ──
                          for (int i = 0;
                              i < arrangedPlayers.length && i < offsets.length;
                              i++)
                            Positioned(
                              left: (activeWidth / 2) +
                                  offsets[i].dx -
                                  avatarHalfW,
                              top: (availableH / 2) +
                                  offsets[i].dy -
                                  avatarHalfH,
                              child: PlayerAvatar(
                                name: arrangedPlayers[i]['name'],
                                cardCount: arrangedPlayers[i]['cardCount'],
                                teamColor:
                                    arrangedPlayers[i]['team'] == teamAName
                                        ? const Color(0xFF6ECFCF)
                                        : const Color(0xFFF4A76F),
                                isMyTurn: gameData['currentTurn'] ==
                                    arrangedPlayers[i]['name'],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- BOTTOM HAND & ACTIONS ---
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FannedHand(
                            myHand: List<Map<String, dynamic>>.from(
                              gameData['myHand'] ?? [],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ActionButtons(
                            myId: myId,
                            gameData: gameData,
                            isMyTurn:
                                !_isPaused && gameData['currentTurn'] == myName,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. PAUSE OVERLAY (Spans the entire device screen)
            if (_isPaused) _buildPauseOverlay(),
          ],
        ),
      ),
    );
  }
}
