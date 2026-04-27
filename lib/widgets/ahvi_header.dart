import 'package:flutter/material.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';
import 'package:myapp/theme/theme_tokens.dart';

/// ── AhviHeader ──────────────────────────────────────────────────────────────
/// One reusable, STATIC header used by Home, Chat, Boards, and Wardrobe.
///
/// Rules that keep it perfectly stable:
///   • It is a StatelessWidget — same props → Flutter skips rebuild entirely.
///   • It uses MediaQuery.sizeOf() for the font-size branch (size-only,
///     no viewInsets subscription → keyboard can't trigger a rebuild here).
///   • It must always be the FIRST child of a Column, NEVER inside
///     AnimatedBuilder / ValueListenableBuilder / setState-heavy widgets.
///
/// Usage examples
/// ──────────────
/// Home (inside Positioned, top: 0):
///   AhviHeader(right: _buildProfileAvatar())
///
/// Chat:
///   AhviHeader(showBack: true, right: IconButton(...historyDrawer))
///
/// Boards / Wardrobe:
///   const AhviHeader()
class AhviHeader extends StatelessWidget {
  /// Show the back-arrow on the left (Chat, detail screens).
  final bool showBack;

  /// Custom back handler. Falls back to Navigator.pop() when null.
  final VoidCallback? onBack;

  /// Optional widget pinned to the right (profile avatar, history icon, etc.).
  final Widget? right;

  /// Draw a hairline bottom border (matches Wardrobe / Chat header style).
  final bool showBorder;

  /// Slight frosted-glass bg so content scrolls cleanly underneath.
  final bool frosted;

  const AhviHeader({
    super.key,
    this.showBack = false,
    this.onBack,
    this.right,
    this.showBorder = false,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    // Use sizeOf — subscribes ONLY to size changes, not viewInsets.
    // Keyboard open/close never triggers a rebuild of this widget.
    final screenH = MediaQuery.sizeOf(context).height;
    final double topPad    = screenH < 700 ? 6.0 : 10.0;
    final double botPad    = screenH < 700 ? 4.0 : 6.0;
    final double logoSize  = screenH < 700 ? 26.0 : 30.0;

    Widget logo = Hero(
      tag: 'ahvi_logo',
      transitionOnUserGestures: true,
      // Shadow తీసేయడానికి: Hero flight లో default overlay shadow వస్తుంది,
      // flightShuttleBuilder తో suppress చేస్తున్నాం
      flightShuttleBuilder: (_, animation, __, ___, ____) {
        return FadeTransition(
          opacity: animation,
          child: AhviHomeText(
            color: t.textPrimary,
            fontSize: logoSize,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w400,
          ),
        );
      },
      child: AhviHomeText(
        color: t.textPrimary,
        fontSize: logoSize,
        letterSpacing: 3.2,
        fontWeight: FontWeight.w400,
      ),
    );

    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: frosted
              ? t.backgroundPrimary.withValues(alpha: 0.92)
              : Colors.transparent,
          border: showBorder
              ? Border(bottom: BorderSide(color: t.cardBorder, width: 1))
              : null,
        ),
        child: SizedBox(
          // Fixed height: topPad + logoSize + botPad (≈ 42-46 px).
          // Consistent across every screen — even 2 px difference is visible.
          height: topPad + logoSize + botPad,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPad, 20, botPad),
            child: Row(
              children: [
                // ── Back button (optional) ───────────────────────────────
                if (showBack) ...[
                  GestureDetector(
                    onTap: onBack ?? () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: t.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],

                // ── AHVI logo — always the visual anchor ─────────────────
                logo,

                const Spacer(),

                // ── Right slot (avatar, history icon, add-item, etc.) ────
                if (right != null) right!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}