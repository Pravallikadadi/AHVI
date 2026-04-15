import 'package:flutter/material.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/theme/theme_tokens.dart';

// ── Convenience function ───────────────────────────────────────────────────
/// Call this from any screen to show the AHVI Lens bottom sheet.
///
/// ```dart
/// // Any chat screen లో:
/// import 'package:myapp/widgets/ahvi_lens_sheet.dart';
///
/// GestureDetector(
///   onTap: () => showAhviLensSheet(context, t: themeTokens),
///   child: Icon(Icons.search_rounded),
/// )
/// ```
void showAhviLensSheet(
  BuildContext context, {
  required AppThemeTokens t,
  VoidCallback? onVisualSearch,
  VoidCallback? onFindSimilar,
  VoidCallback? onAddToWardrobe,
}) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => AhviLensSheet(
      t: t,
      onVisualSearch: onVisualSearch,
      onFindSimilar: onFindSimilar,
      onAddToWardrobe: onAddToWardrobe,
    ),
  );
}

// ── Main sheet widget ──────────────────────────────────────────────────────
class AhviLensSheet extends StatelessWidget {
  final AppThemeTokens t;
  final VoidCallback? onVisualSearch;
  final VoidCallback? onFindSimilar;
  final VoidCallback? onAddToWardrobe;

  const AhviLensSheet({
    super.key,
    required this.t,
    this.onVisualSearch,
    this.onFindSimilar,
    this.onAddToWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    final accent = t.accent.primary;
    final accentSecondary = t.accent.secondary;
    final textHeading = t.textPrimary;
    final textMuted = t.mutedText;
    final panel = t.panel;
    final surface = t.phoneShellInner;
    final bgSecondary = t.backgroundSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [surface, bgSecondary],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 48,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.search, color: accent, size: 17),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t(context, 'lens_title'),
                      style: TextStyle(
                        color: textHeading,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.08),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: Icon(Icons.close, color: textMuted, size: 14),
                  ),
                ),
              ],
            ),
          ),
          // Visual AI Search info card
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onVisualSearch?.call();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: panel,
                border: Border.all(
                  color: accent.withValues(alpha: 0.15),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: accent.withValues(alpha: 0.08),
                    ),
                    child: Icon(Icons.circle, color: accent, size: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.t(context, 'lens_visual_ai_search'),
                          style: TextStyle(
                            color: textHeading,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.t(context, 'lens_visual_ai_desc'),
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Find Similar
          AhviLensOptionTile(
            icon: Icons.search,
            name: AppLocalizations.t(context, 'lens_find_similar'),
            desc: AppLocalizations.t(context, 'lens_find_similar_desc'),
            color: accent,
            textHeading: textHeading,
            textMuted: textMuted,
            panel: panel,
            accentBorder: accent,
            onTap: () {
              Navigator.pop(context);
              onFindSimilar?.call();
            },
          ),
          // Add to Wardrobe
          AhviLensOptionTile(
            icon: Icons.add_photo_alternate_outlined,
            name: AppLocalizations.t(context, 'lens_add_wardrobe'),
            desc: AppLocalizations.t(context, 'lens_add_wardrobe_desc'),
            color: accentSecondary,
            textHeading: textHeading,
            textMuted: textMuted,
            panel: panel,
            accentBorder: accent,
            onTap: () {
              Navigator.pop(context);
              onAddToWardrobe?.call();
            },
          ),
        ],
        ),
      ),
    );
  }
}

// ── Option tile widget ─────────────────────────────────────────────────────
class AhviLensOptionTile extends StatefulWidget {
  final IconData icon;
  final String name;
  final String desc;
  final Color color;
  final Color textHeading;
  final Color textMuted;
  final Color panel;
  final Color accentBorder;
  final VoidCallback onTap;

  const AhviLensOptionTile({
    super.key,
    required this.icon,
    required this.name,
    required this.desc,
    required this.color,
    required this.textHeading,
    required this.textMuted,
    required this.panel,
    required this.accentBorder,
    required this.onTap,
  });

  @override
  State<AhviLensOptionTile> createState() => _AhviLensOptionTileState();
}

class _AhviLensOptionTileState extends State<AhviLensOptionTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.08)
                  : widget.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.30)
                    : widget.accentBorder.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          color: widget.textHeading,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.desc,
                        style: TextStyle(
                          color: widget.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(
                    _hovered ? 3.0 : 0.0,
                    0,
                    0,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _hovered ? widget.color : widget.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}