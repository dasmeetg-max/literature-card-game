import 'dart:async';
import 'dart:math' show cos, sin, pi;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Colour tokens ─────────────────────────────────────────────
const _bg = Color(0xFF0C1A10);
const _surface = Color(0xFF15281A);
const _elevated = Color(0xFF1E3824);
const _border = Color(0xFF2A4A30);
const _peach = Color(0xFFF4A76F);
const _teal = Color(0xFF6ECFCF);
const _red = Color(0xFFE57373);
const _green = Color(0xFF66BB6A);
const _gold = Color(0xFFD4C84A);
const _tan = Color(0xFFC8956C);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFF8AAF90);
const _textHint = Color(0xFF4A6E50);

// "Team Blue" uses the teal colour token throughout
const _blue = _teal;

// ═══════════════════════════════════════════════════════════════
//  ROOT
// ═══════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _tutorialStarted = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startTutorial() => setState(() => _tutorialStarted = true);

  void _backToWelcome() {
    _pageController.jumpToPage(0);
    setState(() {
      _tutorialStarted = false;
      _currentPage = 0;
    });
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_currentPage == 0) {
      _backToWelcome();
    } else {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _tutorialStarted
              ? _TutorialLayer(
                  key: const ValueKey('tutorial'),
                  pageController: _pageController,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  onPrev: _prev,
                  onNext: _next,
                )
              : _WelcomeLayer(
                  key: const ValueKey('welcome'),
                  onHowToPlay: _startTutorial,
                  onSkip: _finish,
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WELCOME LAYER
// ═══════════════════════════════════════════════════════════════

class _WelcomeLayer extends StatelessWidget {
  final VoidCallback onHowToPlay;
  final VoidCallback onSkip;
  const _WelcomeLayer(
      {super.key, required this.onHowToPlay, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo + tagline centred in available space
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/literature_logo_new.png',
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.style_rounded,
                        color: _textHint,
                        size: 80),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'A team card game of deduction,\nmemory, and smart teamwork.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _textSecondary, fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Buttons — same padding as Back/Next
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onHowToPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _peach,
                    foregroundColor: const Color(0xFF3A1A00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('How to Play',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TUTORIAL LAYER
// ═══════════════════════════════════════════════════════════════

class _TutorialLayer extends StatefulWidget {
  final PageController pageController;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _TutorialLayer({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onPrev,
    required this.onNext,
  });

  @override
  State<_TutorialLayer> createState() => _TutorialLayerState();
}

class _TutorialLayerState extends State<_TutorialLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _pulsed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.07), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_TutorialLayer old) {
    super.didUpdateWidget(old);
    // Trigger pulse once when landing on the last slide
    if (widget.currentPage == widget.totalPages - 1 &&
        old.currentPage != widget.totalPages - 1 &&
        !_pulsed) {
      _pulsed = true;
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) _pulseCtrl.forward(from: 0);
      });
    }
    if (widget.currentPage != widget.totalPages - 1) {
      _pulsed = false;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: List.generate(
                widget.totalPages,
                (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= widget.currentPage ? _peach : _border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
          ),
        ),

        // Slides
        Expanded(
          child: PageView(
            controller: widget.pageController,
            onPageChanged: widget.onPageChanged,
            children: const [
              _SlideSetup(),
              _SlideObjective(),
              _SlideTurn(),
              _SlideBroadcast(),
              _SlideDeclaration(),
              _SlideWinning(),
            ],
          ),
        ),

        // Nav buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrev,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back',
                      style: TextStyle(
                          color: _textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: child,
                  ),
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _peach,
                      foregroundColor: const Color(0xFF3A1A00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.currentPage == widget.totalPages - 1
                          ? "Let's Play!"
                          : 'Next',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED SLIDE SHELL
// ═══════════════════════════════════════════════════════════════

class _SlideShell extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final Widget content;

  const _SlideShell({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _elevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _border),
            ),
            child: Text(tag,
                style: const TextStyle(
                    color: _textHint,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6)),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _peach,
                  height: 1.15)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: _textSecondary, height: 1.55)),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: content,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 1 — SETUP
// ═══════════════════════════════════════════════════════════════

class _SlideSetup extends StatefulWidget {
  const _SlideSetup();
  @override
  State<_SlideSetup> createState() => _SlideSetupState();
}

class _SlideSetupState extends State<_SlideSetup>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      tag: 'SETUP',
      title: 'Your team\nvs their team',
      subtitle: 'Six players. Two teams of three.\nNo talking — no signalling.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two-column lobby-style team layout
          _LobbyColumns(ctrl: _ctrl),

          const SizedBox(height: 14),

          // Deck section — label floats above, container has warm tint
          const Text(
            'The Deck',
            style: TextStyle(
              color: _peach,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3020), // slightly warmer than _surface
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(children: const [
                    _CardTile(label: 'A♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '2♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '3♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '4♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '5♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '6♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '7♠', state: _TileState.absent),
                    SizedBox(width: 4),
                    _CardTile(label: '8♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '9♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: '10♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: 'J♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: 'Q♠', state: _TileState.normal),
                    SizedBox(width: 4),
                    _CardTile(label: 'K♠', state: _TileState.normal),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(children: const [
                  Icon(Icons.repeat_rounded, color: _textHint, size: 11),
                  SizedBox(width: 5),
                  Text('Same for Hearts, Diamonds and Clubs',
                      style: TextStyle(color: _textHint, fontSize: 10)),
                ]),
                const SizedBox(height: 10),
                const Text(
                  '48 cards total  ·  No 7s  ·  8 cards dealt to each player',
                  style: TextStyle(
                      color: _textSecondary, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cards are dealt randomly — you don\'t choose your hand.',
                  style: TextStyle(
                      color: _textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Two-column lobby layout with staggered slot animation ──────

class _LobbyColumns extends StatelessWidget {
  final AnimationController ctrl;
  const _LobbyColumns({required this.ctrl});

  static const _blueTeam = ['You', 'Mike', 'Priya'];
  static const _redTeam = ['Sam', 'Ravi', 'Neha'];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team Blue
        Expanded(
          child: _TeamColumn(
            teamName: 'Team Blue',
            teamColor: _blue,
            players: _blueTeam,
            ctrl: ctrl,
            startIndex: 0,
          ),
        ),
        const SizedBox(width: 12),
        // Team Red
        Expanded(
          child: _TeamColumn(
            teamName: 'Team Red',
            teamColor: _red,
            players: _redTeam,
            ctrl: ctrl,
            startIndex: 3,
          ),
        ),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String teamName;
  final Color teamColor;
  final List<String> players;
  final AnimationController ctrl;
  final int startIndex; // stagger offset

  const _TeamColumn({
    required this.teamName,
    required this.teamColor,
    required this.players,
    required this.ctrl,
    required this.startIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header — team name + count pill matching lobby style
        Row(children: [
          Flexible(
            child: Text(
              teamName,
              style: TextStyle(
                fontSize: 14,
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
              '${players.length}/3',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary),
            ),
          ),
        ]),

        const SizedBox(height: 10),

        // Player slots — staggered fade+slide in
        ...players.asMap().entries.map((e) {
          final i = e.key;
          final name = e.value;
          final isYou = name == 'You';
          final globalIndex = startIndex + i;
          final start = globalIndex * 0.10;
          final end = (start + 0.30).clamp(0.0, 1.0);

          final anim = CurvedAnimation(
            parent: ctrl,
            curve: Interval(start, end, curve: Curves.easeOut),
          );

          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Opacity(
              opacity: anim.value,
              child: Transform.translate(
                offset: Offset(0, (1 - anim.value) * 12),
                child: _LobbySlot(
                  name: name,
                  teamColor: teamColor,
                  isYou: isYou,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// Matches _LobbyPlayerSlot style from pre_game_screen.dart
class _LobbySlot extends StatelessWidget {
  final String name;
  final Color teamColor;
  final bool isYou;

  const _LobbySlot({
    required this.name,
    required this.teamColor,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isYou ? teamColor.withOpacity(0.10) : _elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isYou ? teamColor.withOpacity(0.5) : _border,
          width: isYou ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Left colour stripe
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar circle
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: teamColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: teamColor.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                name[0],
                style: TextStyle(
                    color: teamColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + you tag + ready label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary),
                  ),
                  if (isYou) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: teamColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('you',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: teamColor)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                const Text('READY',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF4CAF50))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 2 — OBJECTIVE
// ═══════════════════════════════════════════════════════════════

class _SlideObjective extends StatelessWidget {
  const _SlideObjective();

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      tag: 'OBJECTIVE',
      title: 'Hunt sets.\nScore points.',
      subtitle:
          'Each suit splits into two sets of 6.\nCollect them. Declare them. Win.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('WHAT IS A SET?'),
                const SizedBox(height: 10),
                const Text(
                  'Each suit splits into a Low set (Ace–6) and a High set (8–King). No 7s exist.',
                  style: TextStyle(
                      color: _textSecondary, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                const _MiniLabel('LOW SPADES  ·  Ace to 6'),
                const SizedBox(height: 6),
                _CardRow(cards: const ['A♠', '2♠', '3♠', '4♠', '5♠', '6♠']),
                const SizedBox(height: 10),
                const _MiniLabel('HIGH SPADES  ·  8 to King'),
                const SizedBox(height: 6),
                _CardRow(cards: const ['8♠', '9♠', '10♠', 'J♠', 'Q♠', 'K♠']),
                const SizedBox(height: 8),
                const Text(
                  'Same split for Hearts, Diamonds and Clubs  ·  8 sets total',
                  style: TextStyle(color: _textHint, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SCard(
            leftBorderColor: _peach,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('HOW TO SCORE'),
                const SizedBox(height: 10),
                _GoalRow(
                    icon: Icons.search_rounded,
                    color: _teal,
                    text: 'Collect all 6 cards of a set across your team'),
                const SizedBox(height: 6),
                _GoalRow(
                    icon: Icons.record_voice_over_rounded,
                    color: _peach,
                    text: 'Declare it — name exactly who holds each card'),
                const SizedBox(height: 6),
                _GoalRow(
                    icon: Icons.add_circle_rounded,
                    color: _green,
                    text: 'Nail it and your team scores a point'),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 3 — TURN  (auto-cycling 3-state animation)
// ═══════════════════════════════════════════════════════════════

class _SlideTurn extends StatefulWidget {
  const _SlideTurn();
  @override
  State<_SlideTurn> createState() => _SlideTurnState();
}

class _SlideTurnState extends State<_SlideTurn> with TickerProviderStateMixin {
  int _active = 0;
  Timer? _timer;

  // Hold durations per state: ask, success, failure
  static const _holdMs = [3000, 3000, 3500];

  // One opacity controller per pre-built child
  late final List<AnimationController> _opacityCtrls;

  @override
  void initState() {
    super.initState();
    _opacityCtrls = List.generate(
      3,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 300)),
    );
    // First child starts fully visible
    _opacityCtrls[0].value = 1.0;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(Duration(milliseconds: _holdMs[_active]), _advance);
  }

  void _advance() {
    if (!mounted) return;
    final current = _active;
    final next = (_active + 1) % 3;
    // Fade out current
    _opacityCtrls[current].reverse().then((_) {
      if (!mounted) return;
      setState(() => _active = next);
      // Fade in next
      _opacityCtrls[next].forward().then((_) {
        if (!mounted) return;
        _startTimer();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _opacityCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pre-build all three children — IndexedStack keeps them alive
    final children = [_TurnAsk(), _TurnSuccess(), _TurnFailure()];

    return _SlideShell(
      tag: 'YOUR TURN',
      title: 'Keep the\nstreak alive',
      subtitle: 'Pick a rival. Demand a specific card.\nWatch what happens.',
      content: Column(
        children: [
          _HighlightBox(
            icon: Icons.rule_rounded,
            color: _peach,
            text:
                'You must already hold a card from that set to ask for any card in it.',
          ),
          const SizedBox(height: 14),
          // IndexedStack pre-renders all states; AnimatedOpacity handles crossfade
          IndexedStack(
            index: _active,
            children: List.generate(
                3,
                (i) => AnimatedBuilder(
                      animation: _opacityCtrls[i],
                      builder: (_, __) => Opacity(
                        opacity: _opacityCtrls[i].value,
                        child: children[i],
                      ),
                    )),
          ),
          const SizedBox(height: 16),
          // State dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _active ? _peach : _border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TurnAsk extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SCard(
      leftBorderColor: _peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('THE ASK'),
          const SizedBox(height: 12),
          Row(children: [
            _PlayerBubble(name: 'You', color: _blue, isActive: true),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _peach.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _peach.withOpacity(0.35)),
                ),
                child: const Text('"Sam, give me the Q♠"',
                    style: TextStyle(
                        color: _peach,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            _PlayerBubble(name: 'Sam', color: _red, isActive: false),
          ]),
        ],
      ),
    );
  }
}

class _TurnSuccess extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SCard(
      leftBorderColor: _green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('NICE CATCH!'),
          const SizedBox(height: 12),
          Row(children: [
            _PlayerBubble(name: 'You', color: _blue, isActive: true),
            Expanded(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.arrow_back_rounded, color: _green, size: 20),
                    SizedBox(width: 8),
                    _CardTile(label: 'Q♠', state: _TileState.normal),
                  ]),
            ),
            _PlayerBubble(name: 'Sam', color: _red, isActive: false),
          ]),
          const SizedBox(height: 10),
          _InfoChip(
            icon: Icons.bolt_rounded,
            color: _green,
            text:
                'Sam had it! Card is yours. Your streak continues — ask again!',
          ),
        ],
      ),
    );
  }
}

class _TurnFailure extends StatefulWidget {
  @override
  State<_TurnFailure> createState() => _TurnFailureState();
}

class _TurnFailureState extends State<_TurnFailure>
    with SingleTickerProviderStateMixin {
  late AnimationController _spotCtrl;

  @override
  void initState() {
    super.initState();
    _spotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    // Replay spotlight each time this widget becomes visible
    _replaySpotlight();
  }

  void _replaySpotlight() {
    _spotCtrl.reset();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _spotCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(_TurnFailure oldWidget) {
    super.didUpdateWidget(oldWidget);
    _replaySpotlight();
  }

  @override
  void dispose() {
    _spotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotAnim =
        CurvedAnimation(parent: _spotCtrl, curve: Curves.easeInOut);
    return _SCard(
      leftBorderColor: _red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('DENIED!'),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: spotAnim,
            builder: (_, __) => Row(children: [
              _PlayerBubble(
                name: 'You',
                color:
                    Color.lerp(_blue, _blue.withOpacity(0.25), spotAnim.value)!,
                isActive: spotAnim.value < 0.5,
              ),
              Expanded(
                child: Column(children: [
                  const Text('"No, I don\'t have it."',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _red,
                          fontSize: 10,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Opacity(
                    opacity: spotAnim.value,
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: _red, size: 20),
                  ),
                ]),
              ),
              _PlayerBubble(
                name: 'Sam',
                color: _red,
                isActive: spotAnim.value > 0.5,
              ),
            ]),
          ),
          const SizedBox(height: 10),
          _InfoChip(
            icon: Icons.swap_horiz_rounded,
            color: _red,
            text:
                'Your turn ends instantly. Sam shut you down — Sam hijacks the turn.',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 4 — BROADCAST
// ═══════════════════════════════════════════════════════════════

class _SlideBroadcast extends StatefulWidget {
  const _SlideBroadcast();
  @override
  State<_SlideBroadcast> createState() => _SlideBroadcastState();
}

class _SlideBroadcastState extends State<_SlideBroadcast>
    with SingleTickerProviderStateMixin {
  // Total duration: 6000ms
  //   Phase 1 — ask visible:        0.00 → 0.22  (~1.3s)
  //   Phase 2 — zoom out:           0.22 → 0.48  (~1.6s)
  //   Phase 3 — wave + glows:       0.48 → 0.82  (~2.0s)
  //   Phase 4 — consequences in:    0.80 → 1.00  (~1.2s)
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6500))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consequenceAnim = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.80, 1.0, curve: Curves.easeIn));

    return _SlideShell(
      tag: 'PUBLIC INTEL',
      title: 'Every whisper\nleaves a trace',
      subtitle:
          'You aren\'t just talking to Sam.\nEvery ask is a broadcast to the whole table.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Three-phase oval scene
          _BroadcastScene(ctrl: _ctrl),

          const SizedBox(height: 14),

          // Consequences fade in after wave
          AnimatedBuilder(
            animation: consequenceAnim,
            builder: (_, child) =>
                Opacity(opacity: consequenceAnim.value, child: child!),
            child: Column(
              children: [
                _SCard(
                  leftBorderColor: _red,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.gps_fixed_rounded, color: _red, size: 13),
                        SizedBox(width: 6),
                        _SectionLabel('OPPONENTS HEAR THIS'),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        'They now know you hold High Spades.\nExpect to be targeted.',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _SCard(
                  leftBorderColor: _teal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.groups_rounded, color: _blue, size: 13),
                        SizedBox(width: 6),
                        _SectionLabel('TEAMMATES HEAR THIS TOO'),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        'Your team just got a lead. High Spades is in play.',
                        style:
                            TextStyle(color: _teal, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _HighlightBox(
                  icon: Icons.psychology_rounded,
                  color: _teal,
                  text:
                      'Even when it\'s not your turn, you\'re playing.\nEvery ask at the table is a clue.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Three-phase broadcast scene ───────────────────────────────
//
//  Phase 1 (0.00–0.22): You + Sam large, ask bubble visible
//  Phase 2 (0.22–0.48): zoom out — all 6 appear on oval, bubble fades
//  Phase 3 (0.48–0.82): 3 ripple rings expand from You; players glow
//                        when ring reaches their distance

class _BroadcastScene extends StatelessWidget {
  final AnimationController ctrl;
  const _BroadcastScene({required this.ctrl});

  static const double _sceneH = 200.0;

  // Circle layout — alternating Blue/Red clockwise from left pole
  // Index 0 = You (left pole), Index 3 = Sam (right pole)
  // Positions as unit-circle fractions — mapped to actual coords at build time
  // Angles: You=180°, Ravi=240°, Mike=300°, Sam=0°, Priya=60°, Neha=120°
  static const _players = [
    (name: 'You', team: 'blue', angleDeg: 180.0), // left pole
    (name: 'Ravi', team: 'red', angleDeg: 240.0), // bottom left
    (name: 'Mike', team: 'blue', angleDeg: 300.0), // bottom right
    (name: 'Sam', team: 'red', angleDeg: 0.0), // right pole
    (name: 'Priya', team: 'blue', angleDeg: 60.0), // top right
    (name: 'Neha', team: 'red', angleDeg: 120.0), // top left
  ];

  // Phase boundaries (fraction of total animation 0→1)
  // Total: 6500ms
  // Phase 1 — ask visible:        0.00 → 0.20  (1.3s)
  // Phase 2 — spread to circle:   0.20 → 0.46  (1.7s)
  // Phase 3 — dot wave:           0.46 → 0.80  (2.2s)
  // Phase 4 — consequences in:    0.80 → 1.00  (1.3s)
  static const _p1End = 0.20;
  static const _p2Start = 0.20;
  static const _p2End = 0.46;
  static const _p3Start = 0.46;
  static const _p3End = 0.80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final W = constraints.maxWidth;
      const H = _sceneH;

      // Circle geometry
      final cx = W / 2; // centre x
      final cy = H / 2; // centre y
      final rx = W * 0.38; // horizontal radius
      final ry = H * 0.38; // vertical radius

      // Avatar sizes
      const largeSize = 46.0;
      const normalSize = 34.0;

      // Bubble centre — fixed at scene centre throughout
      final bubbleCx = cx;
      final bubbleCy = cy;

      // Pre-compute circle positions for each player
      final circlePositions = _players.map((p) {
        final rad = p.angleDeg * (pi / 180.0);
        return Offset(cx + rx * cos(rad), cy + ry * sin(rad));
      }).toList();

      // Phase 1 start positions: You left, Sam right, both centred vertically
      final youStart = Offset(W * 0.22, cy);
      final samStart = Offset(W * 0.78, cy);

      // Max distance from bubble centre to any player (for wave timing)
      final maxDist = circlePositions
          .map((p) => (p - Offset(bubbleCx, bubbleCy)).distance)
          .reduce((a, b) => a > b ? a : b);

      return AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          final t = ctrl.value;

          // Phase progress 0→1
          double _phaseP(double start, double end) {
            if (t <= start) return 0.0;
            if (t >= end) return 1.0;
            return (t - start) / (end - start);
          }

          final p2 = Curves.easeInOut.transform(_phaseP(_p2Start, _p2End));
          final p3 = _phaseP(_p3Start, _p3End);

          // Bubble stays visible through all phases
          final bubbleVisible = t >= 0.05;

          return SizedBox(
            width: W,
            height: H,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Circle guide — fades in during phase 2 ────
                if (p2 > 0)
                  Positioned(
                    left: cx - rx - normalSize * 0.6,
                    top: cy - ry - normalSize * 0.6,
                    child: Opacity(
                      opacity: (p2 * 0.5).clamp(0.0, 1.0),
                      child: Container(
                        width: (rx + normalSize * 0.6) * 2,
                        height: (ry + normalSize * 0.6) * 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(200),
                          border: Border.all(color: _border, width: 1),
                        ),
                      ),
                    ),
                  ),

                // ── Dot wave — 3 bursts staggered (phase 3) ───
                ...List.generate(3, (ri) {
                  final burstStart = ri * 0.20;
                  final burstP =
                      ((p3 - burstStart) / (1.0 - burstStart)).clamp(0.0, 1.0);
                  if (burstP <= 0) return const SizedBox.shrink();

                  final burstEased = Curves.easeOut.transform(burstP);
                  final dotRadius = burstEased * (maxDist + 16);
                  final dotOpacity = (1.0 - burstEased).clamp(0.0, 1.0);

                  if (dotOpacity <= 0) return const SizedBox.shrink();

                  // Paint 12 dots evenly spaced around the burst circle
                  const dotCount = 12;
                  return Stack(
                    children: List.generate(dotCount, (di) {
                      final angle = di * (2 * pi / dotCount);
                      final dx = bubbleCx + dotRadius * cos(angle);
                      final dy = bubbleCy + dotRadius * sin(angle);
                      const dotSize = 3.5;
                      return Positioned(
                        left: dx - dotSize / 2,
                        top: dy - dotSize / 2,
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: _peach.withOpacity(dotOpacity * 0.75),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  );
                }),

                // ── Ask bubble — fixed at centre ───────────────
                if (bubbleVisible)
                  Positioned(
                    left: W * 0.30,
                    right: W * 0.30,
                    top: bubbleCy - 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _peach.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _peach.withOpacity(0.45)),
                      ),
                      child: const Text(
                        '"Sam, Q♠?"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _peach,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ── Player avatars ──────────────────────────────
                ...List.generate(_players.length, (i) {
                  final player = _players[i];
                  final color = player.team == 'blue' ? _blue : _red;
                  final isYou = player.name == 'You';
                  final isSam = player.name == 'Sam';
                  final circlePos = circlePositions[i];

                  // Start positions (phase 1): You left, Sam right, others at circle
                  final startPos = isYou
                      ? youStart
                      : isSam
                          ? samStart
                          : circlePos;

                  // Lerp to circle position over phase 2
                  final pos = Offset(
                    lerpDouble(startPos.dx, circlePos.dx, p2)!,
                    lerpDouble(startPos.dy, circlePos.dy, p2)!,
                  );

                  // Size: You + Sam shrink during phase 2; others always normalSize
                  final size = (isYou || isSam)
                      ? lerpDouble(largeSize, normalSize, p2)!
                      : normalSize;

                  // Opacity: You + Sam always 1; others fade in during phase 2
                  final opacity = (isYou || isSam) ? 1.0 : p2.clamp(0.0, 1.0);

                  // Glow:
                  // You + Sam stay at full glow throughout — they are the active players
                  // Others: triggered when dot wave front reaches their distance
                  final double glowIntensity;
                  if (isYou || isSam) {
                    glowIntensity = 1.0;
                  } else {
                    final dist =
                        (circlePos - Offset(bubbleCx, bubbleCy)).distance;
                    final waveRadius = p3 * (maxDist + 16);
                    final hit = waveRadius >= dist * 0.85;
                    glowIntensity = !hit
                        ? 0.0
                        : p3 >= 1.0
                            ? 0.7
                            : (((waveRadius - dist * 0.85) / (maxDist * 0.3))
                                    .clamp(0.0, 1.0) *
                                0.9);
                  }

                  return Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Opacity(
                      opacity: opacity,
                      child: _OvalAvatar(
                        name: player.name,
                        color: color,
                        size: size,
                        glowIntensity: glowIntensity,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );
    });
  }
}

// ── Oval avatar with glow ─────────────────────────────────────

class _OvalAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final double glowIntensity;

  const _OvalAvatar({
    required this.name,
    required this.color,
    required this.size,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final g = glowIntensity.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08 + g * 0.20),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.25 + g * 0.75),
              width: 1.0 + g * 1.5,
            ),
            boxShadow: g > 0.2
                ? [
                    BoxShadow(
                      color: color.withOpacity(g * 0.4),
                      blurRadius: 6 + g * 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              name[0],
              style: TextStyle(
                color: color.withOpacity(0.45 + g * 0.55),
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: size * 0.08),
        Text(
          name,
          style: TextStyle(
            color: g > 0.3 ? _textPrimary : _textHint,
            fontSize: (size * 0.26).clamp(8.0, 11.0),
            fontWeight: g > 0.3 ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 5 — DECLARATION
// ═══════════════════════════════════════════════════════════════

class _SlideDeclaration extends StatefulWidget {
  const _SlideDeclaration();
  @override
  State<_SlideDeclaration> createState() => _SlideDeclarationState();
}

class _SlideDeclarationState extends State<_SlideDeclaration>
    with TickerProviderStateMixin {
  int _active = 0;
  Timer? _timer;
  static const _holdMs = 4000;

  late final List<AnimationController> _opacityCtrls;

  List<Widget> _scenarios = [];

  @override
  void initState() {
    super.initState();

    _rebuildScenarios();

    _opacityCtrls = List.generate(
      3,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 350)),
    );
    _opacityCtrls[0].value = 1.0;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(const Duration(milliseconds: _holdMs), _advance);
  }

  void _rebuildScenarios() {
    _scenarios = [
      _DeclareScenario(
        key: const ValueKey(0),
        label: 'CLUTCH CALL',
        badge: '+1',
        badgeColor: _green,
        borderColor: _green.withOpacity(0.4),
        bgColor: _green.withOpacity(0.06),
        description:
            'Perfect! Every card matched the right teammate. Point secured.',
        isVisible: _active == 0,
        rows: const [
          _RevealData(player: 'You', cards: ['8♠', 'J♠', 'Q♠'], correct: true),
          _RevealData(player: 'Mike', cards: ['9♠', '10♠'], correct: true),
          _RevealData(player: 'Priya', cards: ['K♠'], correct: true),
        ],
      ),
      _DeclareScenario(
        key: const ValueKey(1),
        label: 'HEARTBREAK',
        badge: '0',
        badgeColor: _textSecondary,
        borderColor: _border,
        bgColor: _elevated,
        description:
            'Your team had all 6 but the who-has-what was wrong. No point.',
        isVisible: _active == 1,
        rows: const [
          _RevealData(player: 'You', cards: ['8♠', 'J♠', 'Q♠'], correct: true),
          _RevealData(player: 'Mike', cards: ['K♠'], correct: false),
          _RevealData(player: 'Priya', cards: ['9♠', '10♠'], correct: false),
        ],
      ),
      _DeclareScenario(
        key: const ValueKey(2),
        label: 'BLUNDERED',
        badge: '-1',
        badgeColor: _red,
        borderColor: _red.withOpacity(0.4),
        bgColor: _red.withOpacity(0.06),
        description:
            'An opponent was hiding one of those cards. They steal the point.',
        isVisible: _active == 2,
        rows: const [
          _RevealData(player: 'You', cards: ['8♠', 'J♠', 'Q♠'], correct: true),
          _RevealData(player: 'Mike', cards: ['9♠', '10♠'], correct: true),
          _RevealData(
              player: 'Sam', cards: ['K♠'], correct: false, isOpponent: true),
        ],
      ),
    ];
  }

  void _advance() {
    if (!mounted) return;
    final current = _active;
    final next = (_active + 1) % 3;
    _opacityCtrls[current].reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _active = next;
        _rebuildScenarios();
      });
      _opacityCtrls[next].forward().then((_) {
        if (!mounted) return;
        _startTimer();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _opacityCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      tag: 'THE CLIMAX',
      title: 'Call the set!',
      subtitle: 'Your team holds all 6 High Spades.\nTime to claim your prize.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Static declaration bubble
          _SCard(
            leftBorderColor: _peach,
            child: Row(children: [
              _PlayerBubble(name: 'You', color: _blue, isActive: true),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '"I declare High Spades!\nI have 8, J, Q — Mike has 9, 10 — Priya has K."',
                  style: TextStyle(
                      color: _peach,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      height: 1.5),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 10),

          _HighlightBox(
            icon: Icons.warning_amber_rounded,
            color: _gold,
            text:
                'Name every card AND who holds it.\nA wrong mapping or opponent holding a card gives them the point.',
          ),

          const SizedBox(height: 14),

          // Pre-rendered scenarios — crossfade via AnimatedOpacity
          // IndexedStack sizes to the largest child, eliminating overflow
          IndexedStack(
            index: _active,
            children: List.generate(
                3,
                (i) => AnimatedBuilder(
                      animation: _opacityCtrls[i],
                      builder: (_, __) => Opacity(
                        opacity: _opacityCtrls[i].value,
                        child: _scenarios[i],
                      ),
                    )),
          ),

          const SizedBox(height: 14),

          // Scenario dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _active ? _peach : _border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// Data holder for a reveal row
class _RevealData {
  final String player;
  final List<String> cards;
  final bool correct;
  final bool isOpponent;
  const _RevealData({
    required this.player,
    required this.cards,
    required this.correct,
    this.isOpponent = false,
  });
}

class _DeclareScenario extends StatefulWidget {
  final String label;
  final String badge;
  final Color badgeColor;
  final Color borderColor;
  final Color bgColor;
  final String description;
  final List<_RevealData> rows;
  final bool isVisible;

  const _DeclareScenario({
    super.key,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.borderColor,
    required this.bgColor,
    required this.description,
    required this.rows,
    this.isVisible = false,
  });

  @override
  State<_DeclareScenario> createState() => _DeclareScenarioState();
}

class _DeclareScenarioState extends State<_DeclareScenario> {
  int _revealed = 0;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    // Only start reveal immediately if this scenario is the active one at mount.
    // The other two start via didUpdateWidget when isVisible flips to true.
    if (widget.isVisible) {
      _startReveal();
    }
  }

  void _startReveal() {
    setState(() => _revealed = 0);
    _scheduleReveal();
  }

  void _scheduleReveal() {
    if (_revealed >= widget.rows.length) return;
    _revealTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _revealed++);
      _scheduleReveal();
    });
  }

  @override
  void didUpdateWidget(_DeclareScenario oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart reveal each time this scenario becomes the active one
    if (widget.isVisible && !oldWidget.isVisible) {
      _revealTimer?.cancel();
      _startReveal();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + label
          Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.badgeColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: widget.badgeColor, width: 1.5),
              ),
              child: Text(widget.badge,
                  style: TextStyle(
                      color: widget.badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Text(widget.label,
                style: TextStyle(
                    color: widget.badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4)),
          ]),

          const SizedBox(height: 12),

          // Reveal rows animate in
          ...widget.rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            final color = row.isOpponent ? _red : _blue;
            final tileState =
                row.correct ? _TileState.normal : _TileState.wrong;
            return AnimatedOpacity(
              opacity: i < _revealed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 380),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  Container(
                    width: 40,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(row.player,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ...row.cards.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: _CardTile(label: c, state: tileState),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      row.correct ? Icons.check_rounded : Icons.close_rounded,
                      color: row.correct ? _green : _red,
                      size: 14,
                    ),
                  ),
                ]),
              ),
            );
          }),

          const SizedBox(height: 6),
          Text(widget.description,
              style: const TextStyle(
                  color: _textSecondary, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SLIDE 6 — WINNING
// ═══════════════════════════════════════════════════════════════

class _SlideWinning extends StatefulWidget {
  const _SlideWinning();
  @override
  State<_SlideWinning> createState() => _SlideWinningState();
}

class _SlideWinningState extends State<_SlideWinning>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Smooth double tweens — floored for display, no integer jump choppiness
  late Animation<double> _blueScore;
  late Animation<double> _redScore;

  // Banner: slide starts at 0.60, fade starts slightly later at 0.68
  late Animation<double> _bannerSlide;
  late Animation<double> _bannerFade;

  // Commandments stagger: each row fades in sequentially after scores
  late Animation<double> _cmd1;
  late Animation<double> _cmd2;
  late Animation<double> _cmd3;
  late Animation<double> _cmd4;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..forward();

    _blueScore = Tween<double>(begin: 0, end: 5).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOut)));

    _redScore = Tween<double>(begin: 0, end: 3).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOut)));

    _bannerSlide = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOut));

    _bannerFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.62, 0.85, curve: Curves.easeIn));

    _cmd1 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.72, 0.82, curve: Curves.easeOut));
    _cmd2 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.78, 0.88, curve: Curves.easeOut));
    _cmd3 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.84, 0.94, curve: Curves.easeOut));
    _cmd4 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.90, 1.00, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      tag: 'VICTORY',
      title: 'Most sets.\nMost glory.',
      subtitle:
          'All 8 sets get declared over the game.\nMost points takes everything.',
      content: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scoreboard
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  // Winner banner — slide and fade staggered
                  FadeTransition(
                    opacity: _bannerFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, -0.5), end: Offset.zero)
                          .animate(_bannerSlide),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _blue.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('🏆', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text('Team Blue wins the night!',
                                style: TextStyle(
                                    color: _teal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Score pills — smooth double→int display
                  Row(children: [
                    Expanded(
                      child: _ScoreCard(
                        teamName: 'TEAM BLUE',
                        score: _blueScore.value.floor(),
                        color: _blue,
                        didWin: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('—',
                          style:
                              const TextStyle(color: _textHint, fontSize: 20)),
                    ),
                    Expanded(
                      child: _ScoreCard(
                        teamName: 'TEAM RED',
                        score: _redScore.value.floor(),
                        color: _red,
                        didWin: false,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Commandments — staggered fade in
            _SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('BEFORE YOU PLAY'),
                  const SizedBox(height: 10),
                  _FadingCommandRow(
                    anim: _cmd1,
                    text: 'ASK for cards to keep your hot streak alive',
                  ),
                  const SizedBox(height: 6),
                  _FadingCommandRow(
                    anim: _cmd2,
                    text: 'TRACK every ask at the table — information is power',
                  ),
                  const SizedBox(height: 6),
                  _FadingCommandRow(
                    anim: _cmd3,
                    text:
                        'PROTECT — don\'t reveal which sets your team is building',
                  ),
                  const SizedBox(height: 6),
                  _FadingCommandRow(
                    anim: _cmd4,
                    text: 'DECLARE with absolute certainty to seize the point',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Score card (matching game over screen style) ──────────────

class _ScoreCard extends StatelessWidget {
  final String teamName;
  final int score;
  final Color color;
  final bool didWin;
  const _ScoreCard({
    required this.teamName,
    required this.score,
    required this.color,
    required this.didWin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(teamName,
          style: TextStyle(
              color: didWin ? color : _textHint,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: didWin ? color.withOpacity(0.1) : _elevated,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: didWin ? color : _border, width: didWin ? 1.5 : 1),
          boxShadow: didWin
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 14,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Center(
          child: Text('$score',
              style: const TextStyle(
                  color: _tan,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.0)),
        ),
      ),
    ]);
  }
}

class _FadingCommandRow extends StatelessWidget {
  final Animation<double> anim;
  final String text;
  const _FadingCommandRow({required this.anim, required this.text});

  // Splits "ASK for cards..." into ("ASK", " for cards...")
  // so we can bold the first word independently
  (String, String) _splitKeyword() {
    final spaceIdx = text.indexOf(' ');
    if (spaceIdx == -1) return (text, '');
    return (text.substring(0, spaceIdx), text.substring(spaceIdx));
  }

  @override
  Widget build(BuildContext context) {
    final (keyword, rest) = _splitKeyword();
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child:
                    Icon(Icons.chevron_right_rounded, color: _peach, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, height: 1.5),
                    children: [
                      TextSpan(
                        text: keyword,
                        style: const TextStyle(
                            color: _textPrimary, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: rest,
                        style: const TextStyle(
                            color: _textSecondary, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? leftBorderColor; // Tier 2 scenario cards

  const _SCard({required this.child, this.borderColor, this.leftBorderColor});

  @override
  Widget build(BuildContext context) {
    if (leftBorderColor != null) {
      // Scenario card: left colour stripe + standard border on other sides
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor ?? _border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: leftBorderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? _border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textHint,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

/// Section header inside Tier 2/3 cards — more readable than _Label
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4));
}

class _MiniLabel extends StatelessWidget {
  final String text;
  const _MiniLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style:
          const TextStyle(color: _textHint, fontSize: 10, letterSpacing: 0.5));
}

enum _TileState { highlight, normal, ghost, wrong, absent }

class _CardTile extends StatelessWidget {
  final String label;
  final _TileState state;
  const _CardTile({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color bg, border, text;
    switch (state) {
      case _TileState.highlight:
        bg = _peach.withOpacity(0.15);
        border = _peach.withOpacity(0.7);
        text = _peach;
        break;
      case _TileState.ghost:
        bg = _elevated;
        border = _border;
        text = _textHint;
        break;
      case _TileState.wrong:
        bg = _red.withOpacity(0.1);
        border = _red.withOpacity(0.6);
        text = _red;
        break;
      case _TileState.absent:
        bg = Colors.white;
        border = const Color(0xFFDDDDDD);
        text = const Color(0xFF222222);
        break;
      case _TileState.normal:
      default:
        bg = Colors.white;
        border = const Color(0xFFDDDDDD);
        text = const Color(0xFF111111);
    }

    final isAbsent = state == _TileState.absent;

    return Container(
      width: 34,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border, width: 1),
        boxShadow: (state == _TileState.normal || state == _TileState.absent)
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ]
            : null,
      ),
      child: isAbsent
          ? Stack(
              alignment: Alignment.center,
              children: [
                // Card label dimmed
                Text(
                  label,
                  style: TextStyle(
                      color: text.withOpacity(0.25),
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
                // Red cross overlay
                const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFDD2222),
                  size: 20,
                ),
              ],
            )
          : Text(label,
              style: TextStyle(
                  color: text, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _CardRow extends StatelessWidget {
  final List<String> cards;
  const _CardRow({required this.cards});
  @override
  Widget build(BuildContext context) => Row(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: _CardTile(label: c, state: _TileState.normal),
                ))
            .toList(),
      );
}

class _PlayerBubble extends StatelessWidget {
  final String name;
  final Color color;
  final bool isActive;
  const _PlayerBubble(
      {required this.name, required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: isActive ? color : color.withOpacity(0.3),
                width: isActive ? 2 : 1),
          ),
          child: Center(
            child: Text(name[0],
                style: TextStyle(
                    color: isActive ? color : color.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 3),
        Text(name,
            style: TextStyle(
                color: isActive ? _textPrimary : _textHint,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoChip(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 7),
        Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 11, height: 1.4))),
      ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ]);
}

class _HighlightBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _HighlightBox(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12, height: 1.5))),
        ]),
      );
}

class _GoalRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _GoalRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 12, height: 1.45))),
        ],
      );
}
