// lib/theme/app_widgets.dart
//
// Small, reusable UI pieces that match the mockup design.
// Import this wherever you need a slot, badge, or pill widget.

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────
//  1. PLAYER SLOT — the rounded rectangle row inside a team list
//     Shows avatar + name + ready/waiting status.
//     Used on the Lobby screen for each team member.
// ─────────────────────────────────────────────────────────────────

class AppPlayerSlot extends StatelessWidget {
  /// The player's display name. Pass null to show an "Invite Friend" slot.
  final String? name;

  /// True = green "READY" label, false = muted "WAITING..." label.
  final bool isReady;

  /// The team accent color — used as the left border stripe.
  final Color teamColor;

  /// Pass true when this slot belongs to the current user.
  final bool isMe;

  const AppPlayerSlot({
    super.key,
    required this.name,
    this.isReady = false,
    required this.teamColor,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = name == null;

    if (isEmpty) {
      return _InviteSlot(teamColor: teamColor);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Left colored stripe
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar circle
          _PlayerAvatar(teamColor: teamColor),
          const SizedBox(width: 14),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(
                  isMe ? '$name (you)' : name!,
                  style: AppTextStyles.playerName,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isReady ? 'READY' : 'WAITING...',
                  style: AppTextStyles.statusLabel.copyWith(
                    color: isReady
                        ? AppColors.statusReady
                        : AppColors.statusWaiting,
                  ),
                ),
              ],
            ),
          ),
          // Drag handle dots (cosmetic)
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(
              Icons.drag_indicator,
              color: AppColors.textHint,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// Small circular avatar used inside AppPlayerSlot
class _PlayerAvatar extends StatelessWidget {
  final Color teamColor;
  const _PlayerAvatar({required this.teamColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundCard,
        border: Border.all(color: teamColor, width: 2),
      ),
      child: const Icon(Icons.person, color: Colors.white54, size: 26),
    );
  }
}

// The dashed "INVITE FRIEND" empty slot
class _InviteSlot extends StatelessWidget {
  final Color teamColor;
  const _InviteSlot({required this.teamColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderDashed,
          width: 1.5,
          // Flutter doesn't support native dashed borders natively,
          // so we simulate it with a low-opacity solid border.
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline,
              color: AppColors.textHint, size: 20),
          SizedBox(width: 10),
          Text('INVITE FRIEND', style: AppTextStyles.inviteSlot),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  2. TEAM SCORE PILL — shown top-left / top-right on the game board
//     Contains team name label + big score number.
// ─────────────────────────────────────────────────────────────────

class AppScorePill extends StatelessWidget {
  final String teamName;
  final int    score;
  final Color  teamColor;

  const AppScorePill({
    super.key,
    required this.teamName,
    required this.score,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teamColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            teamName.toUpperCase(),
            style: AppTextStyles.scoreTeamName.copyWith(color: teamColor),
          ),
          const SizedBox(height: 2),
          Text('$score', style: AppTextStyles.scoreNumber),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  3. BOTTOM NAV BAR — shared navigation at the bottom of each screen
// ─────────────────────────────────────────────────────────────────

class AppBottomNavBar extends StatelessWidget {
  /// Which tab is currently active: 0 = Home, 1 = Friends, 2 = Settings
  final int currentIndex;
  final void Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap:        onTap,
      items: const [
        BottomNavigationBarItem(
          icon:  Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon:  Icon(Icons.people_alt_rounded),
          label: 'Friends',
        ),
        BottomNavigationBarItem(
          icon:  Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  4. SECTION TILE — "RULES" / "FRIENDS LIST" grid tiles on home screen
// ─────────────────────────────────────────────────────────────────

class AppSectionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback? onTap;

  const AppSectionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 28),
            const SizedBox(height: 10),
            Text(label, style: AppTextStyles.sectionLabel),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  5. ROOM CODE DISPLAY — large code + share button
// ─────────────────────────────────────────────────────────────────

class AppRoomCodeDisplay extends StatelessWidget {
  final String code;
  final VoidCallback? onShare;

  const AppRoomCodeDisplay({
    super.key,
    required this.code,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('ROOM CODE', style: AppTextStyles.roomCodeLabel),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(code, style: AppTextStyles.roomCode),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onShare,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.share_rounded,
                  color: AppColors.peach,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
