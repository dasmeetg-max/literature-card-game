import 'package:flutter/material.dart';
import 'playing_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TableEventSplash extends StatelessWidget {
  final String eventType;
  final String subtitle;
  final Map<String, dynamic>? card;
  final List<Map<String, dynamic>>? set;

  const TableEventSplash({
    required this.eventType,
    this.subtitle = '',
    this.card,
    this.set,
    super.key,
  });

  int _rankOrder(String rank) {
    const order = {
      'A': 1,
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
      '8': 8,
      '9': 9,
      '10': 10,
      'J': 11,
      'Q': 12,
      'K': 13,
    };
    return order[rank] ?? 0;
  }

  Widget _buildSetVisual(List<Map<String, dynamic>>? set) {
    if (set == null || set.isEmpty) return const SizedBox.shrink();

    final sorted = [...set]
      ..sort((a, b) => _rankOrder(a['rank']).compareTo(_rankOrder(b['rank'])));

    const double cardSize = 0.3;
    const double cardWidth = 80 * cardSize;
    const double cardHeight = 120 * cardSize;
    const double overlap = 16.0;
    final totalWidth = cardWidth + (sorted.length - 1) * overlap;

    return SizedBox(
      width: totalWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(sorted.length, (i) {
          final c = sorted[i];
          final suitColor = (c['suit'] == '♥' || c['suit'] == '♦')
              ? Colors.red
              : Colors.black;
          return Positioned(
            left: i * overlap,
            child: PlayingCard(
              rank: c['rank'],
              suit: c['suit'],
              color: suitColor,
              size: cardSize,
              rightMargin: 0,
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (eventType == 'none') {
      return const AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: SizedBox.shrink(key: ValueKey('none')),
      );
    }

    final cardData = card;

    Color glowColor;
    IconData icon;
    String title;
    String displaySubtitle;
    Widget visual;

    switch (eventType) {
      case 'ask_success':
        glowColor = AppColors.statusReady;
        icon = Icons.check_circle_outline;
        title = "CARD STOLEN";
        displaySubtitle = subtitle.isNotEmpty ? subtitle : "Card transferred";
        visual = cardData != null
            ? _buildSingleCard(cardData)
            : const SizedBox.shrink();
        break;

      case 'ask_fail':
        glowColor = AppColors.teamOrangeRing;
        icon = Icons.close;
        title = "DENIED";
        displaySubtitle = subtitle.isNotEmpty ? subtitle : "Card not found";
        visual = cardData != null
            ? _buildSingleCard(cardData)
            : const SizedBox.shrink();
        break;

      case 'declare_success':
        glowColor = AppColors.buttonDeclare;
        icon = Icons.emoji_events;
        title = "SET DECLARED";
        displaySubtitle =
            subtitle.isNotEmpty ? subtitle : "Declaring team scores";
        visual = _buildSetVisual(set);
        break;

      case 'declare_fail':
        glowColor = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        title = "DECLARATION FAILED";
        displaySubtitle =
            subtitle.isNotEmpty ? subtitle : "Defending team gets the point";
        visual = _buildSetVisual(set);
        break;

      case 'mapping_failed':
        glowColor = Colors.redAccent;
        icon = Icons.shuffle;
        title = "WRONG MAPPING";
        displaySubtitle =
            subtitle.isNotEmpty ? subtitle : "Defending team gets the point";
        visual = _buildSetVisual(set);
        break;

      default:
        return const SizedBox.shrink();
    }

    // A shared heavy shadow to make text pop against the green table without a container
    final textShadow = Shadow(
      color: Colors.black.withValues(alpha: 0.9),
      blurRadius: 10,
      offset: const Offset(0, 2),
    );

    final splashContent = SizedBox(
      key: ValueKey('$eventType-$subtitle'),
      width: 200, // STRICT constraint: Ensures it never reaches the avatars
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          visual,
          if (visual is! SizedBox) const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: glowColor,
                size: 22,
                shadows: [textShadow],
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.eventTitle.copyWith(
                    color: glowColor,
                    fontSize: 16,
                    shadows: [textShadow],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displaySubtitle,
            style: AppTextStyles.eventSubtitle.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
              shadows: [textShadow],
            ),
            textAlign: TextAlign.center,
            maxLines: 3, // Allow wrapping since width is tightly constrained
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      child: splashContent,
    );
  }

  Widget _buildSingleCard(Map<String, dynamic> cardData) {
    final suitColor = (cardData['suit'] == '♥' || cardData['suit'] == '♦')
        ? Colors.red
        : Colors.black;
    return PlayingCard(
      rank: cardData['rank'],
      suit: cardData['suit'],
      color: suitColor,
      size: 0.5,
      rightMargin: 0,
    );
  }
}
