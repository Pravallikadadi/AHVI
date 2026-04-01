import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/services/appwrite_service.dart';

// ── Data model ───────────────────────────────────────────────────────────────
class LookItem {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String category;
  final String? imageUrl;
  final LookBadgeStyle badge;
  final LookBgStyle bg;

  const LookItem({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.category,
    this.imageUrl,
    required this.badge,
    required this.bg,
  });
}

enum LookBadgeStyle { streetwear, athleisure, boho, minimalist, vintage, monochrome, cottagecore, defaultBadge }
enum LookBgStyle { streetwear, athleisure, boho, minimalist, vintage, monochrome, cottagecore, defaultBg }

// ── Main Screen ──────────────────────────────────────────────────────────────
class OccasionBoard extends StatefulWidget {
  final String occasion;
  final String title;
  final String subtitle;
  final String emptyEmoji;

  const OccasionBoard({
    super.key, 
    required this.occasion,
    required this.title,
    required this.subtitle,
    this.emptyEmoji = '✨',
  });

  @override
  State<OccasionBoard> createState() => _OccasionBoardState();
}

class _OccasionBoardState extends State<OccasionBoard> {
  AppThemeTokens get _t => context.themeTokens;
  Color get _bg => _t.backgroundPrimary;
  Color get _bg2 => _t.backgroundSecondary;
  Color get _phoneShell => _t.phoneShell;
  Color get _text => _t.textPrimary;

  bool _isLoading = true;
  String? _toastMessage;
  List<LookItem> _looks = [];

  @override
  void initState() {
    super.initState();
    _fetchLooks();
  }

  Future<void> _fetchLooks() async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      // 🔥 Fetch dynamically based on the parameter passed from boards.dart!
      final docs = await appwrite.getSavedBoardsByOccasion(widget.occasion);

      final List<LookItem> loadedLooks = [];

      for (var doc in docs) {
        // Pick a dynamic badge based on string length to give it that varied Pinterest feel
        final badgeIndex = doc.$id.length % LookBadgeStyle.values.length;
        final dynamicBadge = LookBadgeStyle.values[badgeIndex];
        final dynamicBg = LookBgStyle.values[badgeIndex];

        loadedLooks.add(LookItem(
          id: doc.$id,
          title: doc.data['occasion'] ?? widget.occasion, 
          description: doc.data['outfitDescription'] ?? 'Custom ${widget.occasion} inspiration',
          emoji: doc.data['emoji'] ?? widget.emptyEmoji, 
          category: widget.occasion,
          imageUrl: doc.data['imageUrl'],
          badge: dynamicBadge,
          bg: dynamicBg,
        ));
      }

      if (mounted) {
        setState(() {
          _looks = loadedLooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showToast('Failed to load looks.');
    }
  }

  Future<void> _deleteLook(String id) async {
    setState(() => _looks.removeWhere((l) => l.id == id));
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      await appwrite.deleteSavedBoard(id);
      _showToast('Look removed');
    } catch (e) {
      _showToast('Failed to delete from cloud');
    }
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final countText = _looks.isEmpty
        ? 'No looks saved yet'
        : '${_looks.length} look${_looks.length != 1 ? 's' : ''} saved';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
                colors: [_bg, _bg2, _bg],
              ),
            ),
          ),
          Column(
            children: [
              // ── HEADER ──
              _Header(
                countText: countText, 
                title: widget.title, 
                subtitle: widget.subtitle
              ),
              
              // ── GRID SCROLL AREA ──
              Expanded(
                child: Container(
                  color: _bg,
                  child: _isLoading 
                      ? Center(child: CircularProgressIndicator(color: _t.accent.primary))
                      : _looks.isEmpty
                          ? _EmptyState(title: widget.title, emoji: widget.emptyEmoji)
                          : _LooksGrid(
                              looks: _looks,
                              onDelete: _deleteLook,
                              onShare: (look) => _showToast('Copied!'),
                            ),
                ),
              ),
            ],
          ),
          // ── TOAST ──
          if (_toastMessage != null)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _phoneShell,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _toastMessage!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String countText;
  final String title;
  final String subtitle;
  
  const _Header({
    required this.countText, 
    required this.title, 
    required this.subtitle
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 48, 14, 16), 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
          colors: [t.phoneShellInner, t.phoneShell, t.backgroundSecondary],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [t.accent.tertiary.withValues(alpha: 0.30), t.backgroundPrimary.withValues(alpha: 0.0)],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [t.accent.primary.withValues(alpha: 0.22), t.backgroundPrimary.withValues(alpha: 0.0)],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: t.textPrimary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.accent.tertiary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: t.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Looks Grid ───────────────────────────────────────────────────────────────
class _LooksGrid extends StatelessWidget {
  final List<LookItem> looks;
  final ValueChanged<String> onDelete;
  final ValueChanged<LookItem> onShare;
  const _LooksGrid({required this.looks, required this.onDelete, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    final List<Widget> rows = [];
    int i = 0;

    // First card is "featured" (full-width)
    if (looks.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LookCard(look: looks[0], featured: true, onDelete: onDelete, onShare: onShare),
        ),
      );
      i = 1;
    }

    // Remaining cards in 2-column pairs
    while (i < looks.length) {
      final left = looks[i];
      final right = i + 1 < looks.length ? looks[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _LookCard(look: left, featured: false, onDelete: onDelete, onShare: onShare)),
              const SizedBox(width: 12),
              Expanded(
                child: right != null
                    ? _LookCard(look: right, featured: false, onDelete: onDelete, onShare: onShare)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      i += 2;
    }

    return Column(children: rows);
  }
}

// ── Look Card ────────────────────────────────────────────────────────────────
class _LookCard extends StatefulWidget {
  final LookItem look;
  final bool featured;
  final ValueChanged<String> onDelete;
  final ValueChanged<LookItem> onShare;

  const _LookCard({
    required this.look,
    required this.featured,
    required this.onDelete,
    required this.onShare,
  });

  @override
  State<_LookCard> createState() => _LookCardState();
}

class _LookCardState extends State<_LookCard> {
  bool _hovered = false;
  AppThemeTokens get _t => context.themeTokens;

  Gradient _bgGradient(LookBgStyle bg) {
    switch (bg) {
      case LookBgStyle.streetwear:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.secondary.withValues(alpha: 0.15), _t.accent.primary.withValues(alpha: 0.18)],
        );
      case LookBgStyle.athleisure:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.tertiary.withValues(alpha: 0.18), _t.accent.primary.withValues(alpha: 0.15)],
        );
      case LookBgStyle.boho:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.secondary.withValues(alpha: 0.22), _t.accent.tertiary.withValues(alpha: 0.16)],
        );
      case LookBgStyle.minimalist:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.primary.withValues(alpha: 0.12), _t.accent.secondary.withValues(alpha: 0.10)],
        );
      case LookBgStyle.vintage:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.secondary.withValues(alpha: 0.22), _t.accent.tertiary.withValues(alpha: 0.20)],
        );
      case LookBgStyle.monochrome:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.phoneShell.withValues(alpha: 0.60), _t.phoneShellInner.withValues(alpha: 0.50)],
        );
      case LookBgStyle.cottagecore:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.tertiary.withValues(alpha: 0.14), _t.accent.secondary.withValues(alpha: 0.20)],
        );
      case LookBgStyle.defaultBg:
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_t.accent.primary.withValues(alpha: 0.12), _t.accent.tertiary.withValues(alpha: 0.10)],
        );
    }
  }

  Color _badgeColor(LookBadgeStyle badge) {
    switch (badge) {
      case LookBadgeStyle.streetwear: return _t.accent.secondary;
      case LookBadgeStyle.athleisure: return _t.accent.tertiary;
      case LookBadgeStyle.boho: return _t.accent.secondary;
      case LookBadgeStyle.minimalist: return _t.accent.primary;
      case LookBadgeStyle.vintage: return _t.accent.secondary;
      case LookBadgeStyle.monochrome: return _t.mutedText;
      case LookBadgeStyle.cottagecore: return _t.accent.tertiary;
      case LookBadgeStyle.defaultBadge: return _t.accent.tertiary;
    }
  }

  Color _badgeBg(LookBadgeStyle badge) {
    switch (badge) {
      case LookBadgeStyle.streetwear: return _t.accent.secondary.withValues(alpha: 0.15);
      case LookBadgeStyle.athleisure: return _t.accent.tertiary.withValues(alpha: 0.15);
      case LookBadgeStyle.boho: return _t.accent.secondary.withValues(alpha: 0.20);
      case LookBadgeStyle.minimalist: return _t.accent.primary.withValues(alpha: 0.15);
      case LookBadgeStyle.vintage: return _t.accent.secondary.withValues(alpha: 0.16);
      case LookBadgeStyle.monochrome: return _t.panel;
      case LookBadgeStyle.cottagecore: return _t.accent.tertiary.withValues(alpha: 0.14);
      case LookBadgeStyle.defaultBadge: return _t.panel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final aspectRatio = widget.featured ? 2.0 : 1.0;
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? _t.accent.tertiary : _t.cardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? _t.accent.tertiary.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: _hovered ? 28 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image / placeholder
              Stack(
                children: [
                  look.imageUrl != null && look.imageUrl!.isNotEmpty
                      ? AspectRatio(
                          aspectRatio: aspectRatio,
                          child: Image.network(
                            look.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: aspectRatio,
                          child: Container(
                            decoration: BoxDecoration(gradient: _bgGradient(look.bg)),
                            child: Center(
                              child: Text(look.emoji, style: const TextStyle(fontSize: 32)),
                            ),
                          ),
                        ),
                  // Delete button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () => widget.onDelete(look.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _t.phoneShellInner.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: _t.cardBorder, width: 1),
                          ),
                          child: Center(
                            child: Icon(Icons.close, size: 14, color: _t.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Card info
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeBg(look.badge),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        look.category.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: _badgeColor(look.badge),
                        ),
                      ),
                    ),
                    // Title
                    Text(
                      look.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _t.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      look.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: _t.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Try On button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_t.accent.tertiary, _t.accent.primary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _t.accent.tertiary.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: onAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Try On',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: onAccent,
                          ),
                        ),
                      ],
                    ),
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

// ── Empty / No-results states ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String title;
  final String emoji;
  const _EmptyState({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              'No $title yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save your favorite looks from the AI chat and they\'ll automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: t.mutedText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}