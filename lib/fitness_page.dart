import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/app_localizations.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';
// ─── DATA MODELS ──────────────────────────────────────────────────────────────
class WorkoutCategory {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final Color accent;
  const WorkoutCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    this.accent = Colors.black,
  });
}
class WorkoutOutfit {
  final String id;
  final String name;
  final String catId;
  final List<String> images;
  final List<String> items;
  final String notes;
  const WorkoutOutfit({
    required this.id,
    required this.name,
    required this.catId,
    this.images = const [],
    this.items = const [],
    this.notes = '',
  });
  String? get mainImage => images.isNotEmpty ? images.first : null;
}
class WorkoutStyleboard {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final List<Color> gradientColors;
  const WorkoutStyleboard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.gradientColors,
  });
}
// ─── THEME COLORS (FIXED — dynamic via AppThemeTokens) ────────────────────────
// kAccent & navy palette stay constant; surface/text/bg colors come from context
const kAccent = Color(0xFF7B6EF6);
const kGlassBg = Color(0x1AFFFFFF);
const kGlassBgStrong = Color(0x30FFFFFF);
const kGlassBorder = Color(0x30FFFFFF);

// ─── THEME HELPERS ─────────────────────────────────────────────────────────────
extension FitnessTheme on BuildContext {
  AppThemeTokens get _t => Theme.of(this).extension<AppThemeTokens>()!;
  Color get fText => _t.textPrimary;
  Color get fTextSoft => _t.textPrimary.withValues(alpha: 0.85);
  Color get fMuted => _t.mutedText;
  Color get fSurface => _t.backgroundSecondary;
  Color get fCard => _t.card;
  Color get fBg => _t.backgroundPrimary;
  Color get fBorder => _t.cardBorder;
  Color get fPanel => _t.panel;
  Color get fPanelBorder => _t.panelBorder;
  Color get fAccent => _t.accent.primary;
  Color get fAccent2 => _t.accent.secondary;
  Color get fSnackBg => _t.backgroundPrimary.computeLuminance() > 0.5
      ? const Color(0xFF1C1C1E)
      : const Color(0xFF2C2C2E);
  bool get fIsDark => _t.backgroundPrimary.computeLuminance() < 0.5;
  LinearGradient get fPageBgGrad => fIsDark
      ? const LinearGradient(
          colors: [Color(0xFF0F0F18), Color(0xFF141428), Color(0xFF0F0F1E), Color(0xFF12121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFFEEF3FF), Color(0xFFF5F7FF), Color(0xFFEEF3FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

// ─── NAVY BLUE PALETTE (OUTFIT CARD) ──────────────────────────────────────────
const kNavyDeep    = Color(0xFF0A1628); // darkest navy
const kNavyMid     = Color(0xFF1B3A6B); // mid navy blue
const kNavyBright  = Color(0xFF2563EB); // vivid navy/royal blue
const kNavyLight   = Color(0xFF3B82F6); // lighter accent blue
const kNavySoft    = Color(0xFF93C5FD); // soft sky-navy highlight
final kAccentGrad = const LinearGradient(
  colors: [Color(0xFF7B6EF6), Color(0xFF9B8EFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
// ─── MAIN SCREEN ──────────────────────────────────────────────────────────────
class WorkoutStudioScreen extends StatefulWidget {
  const WorkoutStudioScreen({super.key});
  @override
  State<WorkoutStudioScreen> createState() => _WorkoutStudioScreenState();
}
class _WorkoutStudioScreenState extends State<WorkoutStudioScreen> {
  String _selectedTab = 'all';
  
  late List<WorkoutCategory> _categories;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories = [
      WorkoutCategory(id: 'running', label: AppLocalizations.t(context, 'fitness_cat_running'), emoji: '🏃', color: const Color(0xD9F5C842), accent: Colors.black),
      WorkoutCategory(id: 'gym', label: AppLocalizations.t(context, 'fitness_cat_gym'), emoji: '🏋️', color: const Color(0xE6A8D4F0), accent: Colors.black),
      WorkoutCategory(id: 'yoga', label: AppLocalizations.t(context, 'fitness_cat_yoga'), emoji: '🧘', color: const Color(0xE6C8B0F5), accent: Colors.black),
      WorkoutCategory(id: 'hiit', label: AppLocalizations.t(context, 'fitness_cat_hiit'), emoji: '⚡', color: const Color(0xE6F068B0), accent: Colors.white),
    ];
  }
  void _addCategory(WorkoutCategory c) {
    setState(() => _categories.add(c));
  }
  final List<WorkoutOutfit> _outfits = [];
  void _addOutfit(WorkoutOutfit o) {
    setState(() => _outfits.insert(0, o));
  }
  void _deleteOutfit(String id) {
    setState(() => _outfits.removeWhere((o) => o.id == id));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient — theme aware
          Container(decoration: BoxDecoration(gradient: context.fPageBgGrad)),
          
          // Floating Orbs
          const _BgOrbs(),
          // Main View
          SafeArea(
            child: _HomeView(
              categories: _categories,
              outfits: _outfits,
              selectedTab: _selectedTab,
              onTabSelected: (id) => setState(() => _selectedTab = id),
              onShowPage: (name) {},
              onAddOutfit: _addOutfit,
              onDeleteOutfit: _deleteOutfit,
              onAddCategory: _addCategory,
            ),
          ),
          // FAB — pinned bottom-right
          Positioned(
            bottom: 30,
            right: 20,
            child: _AskAhviFab(onTap: () => showAhviStylistChatSheet(context, moduleContext: 'fitness')),
          ),
        ],
      ),
    );
  }
}
// ─── BACKGROUND ORBS ─────────────────────────────────────────────────────────
class _BgOrbs extends StatelessWidget {
  const _BgOrbs();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -120,
          child: Container(
            width: 520,
            height: 520,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [const Color(0xFFB4A0F0).withValues(alpha: 0.35), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [const Color(0xFFC8AAFA).withValues(alpha: 0.30), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ─── HOME VIEW ────────────────────────────────────────────────────────────────
class _HomeView extends StatelessWidget {
  final List<WorkoutCategory> categories;
  final List<WorkoutOutfit> outfits;
  final String selectedTab;
  final Function(String) onTabSelected;
  final Function(String) onShowPage;
  final Function(WorkoutOutfit) onAddOutfit;
  final Function(String) onDeleteOutfit;
  final Function(WorkoutCategory) onAddCategory;
  const _HomeView({
    required this.categories,
    required this.outfits,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onShowPage,
    required this.onAddOutfit,
    required this.onDeleteOutfit,
    required this.onAddCategory,
  });
  @override
  Widget build(BuildContext context) {
    final filtered = selectedTab == 'all' ? outfits : outfits.where((o) => o.catId == selectedTab).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── PAGE HEADER ──────────────────────────────────────────────
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.fitness_center_rounded, color: context.fText, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitness',
                    style: GoogleFonts.anton(fontSize: 22, color: context.fText, letterSpacing: 0.5),
                  ),

                ],
              ),
            ],
          ),
          // ─────────────────────────────────────────────────────────────
          const SizedBox(height: 16),
          // Hero Card: Dress well, train better
          _HeroCard(),
          const SizedBox(height: 24),
          // Saved Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${AppLocalizations.t(context, 'fitness_your_routines')} — ${outfits.length} ${AppLocalizations.t(context, 'fitness_saved')}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.2, color: context.fMuted)),
              ElevatedButton(
                onPressed: () => _openAddOutfit(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.fAccent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text(AppLocalizations.t(context, 'fitness_add_routine')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tabs Row
          _CategoryTabs(
            categories: categories,
            selectedId: selectedTab,
            onSelect: onTabSelected,
            totalCount: outfits.length,
            onAddType: onAddCategory,
          ),
          const SizedBox(height: 10),
          // Grid
          Expanded(
            child: filtered.isEmpty
                ? _EmptyGrid()
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _OutfitCard(
                      outfit: filtered[i],
                      category: categories.firstWhere((c) => c.id == filtered[i].catId, orElse: () => categories[0]),
                      onDelete: () => onDeleteOutfit(filtered[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  void _openAddOutfit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddOutfitSheet(
        onSave: (o) {
          onAddOutfit(o);
          Navigator.pop(ctx);
        },
        categories: categories,
      ),
    );
  }
}
// ─── HERO CARD: DRESS WELL, TRAIN BETTER ──────────────────────────────────────
// Quote keys — values live in assets/l10n/*.json
const _kFitnessQuoteKeys = [
  (quoteKey: 'fitness_hero_quote_1', subKey: 'fitness_hero_sub_1', captionKey: 'fitness_hero_caption_1'),
  (quoteKey: 'fitness_hero_quote_2', subKey: 'fitness_hero_sub_2', captionKey: 'fitness_hero_caption_2'),
  (quoteKey: 'fitness_hero_quote_3', subKey: 'fitness_hero_sub_3', captionKey: 'fitness_hero_caption_3'),
  (quoteKey: 'fitness_hero_quote_4', subKey: 'fitness_hero_sub_4', captionKey: 'fitness_hero_caption_4'),
  (quoteKey: 'fitness_hero_quote_5', subKey: 'fitness_hero_sub_5', captionKey: 'fitness_hero_caption_5'),
];

class _HeroCard extends StatefulWidget {
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF9B7FD4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC8B4F5).withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: const Color(0xFF9B7FD4).withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Right-side image
          Positioned(
            right: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.5,
            height: 260,
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/hero_outfit.jpg',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 48)),
              ),
            ),
          ),
          // Left-side gradient overlay so text is always readable
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.58,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9B7FD4).withValues(alpha: 1.0),
                    const Color(0xFF9B7FD4).withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          // Quote text — constrained to left half, rendered above gradient
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.t(context, _kFitnessQuoteKeys[0].quoteKey),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t(context, _kFitnessQuoteKeys[0].subKey),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.80),
                      letterSpacing: 0.2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.t(context, _kFitnessQuoteKeys[0].captionKey),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─── STUBS FOR COMPLETION IN NEXT TURN ────────────────────────────────────────
class _AskAhviFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AskAhviFab({required this.onTap});
  @override
  State<_AskAhviFab> createState() => _AskAhviFabState();
}

class _AskAhviFabState extends State<_AskAhviFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.fAccent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _pulseOpacity.value,
                  child: Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.40),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: const Text(
                    '✦',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  AppLocalizations.t(context, 'diet_ask_ahvi'),
                  style: GoogleFonts.anton(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: Colors.white,
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
class _CategoryTabs extends StatelessWidget {
  final List<WorkoutCategory> categories;
  final String selectedId;
  final Function(String) onSelect;
  final int totalCount;
  final Function(WorkoutCategory) onAddType;
  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.totalCount,
    required this.onAddType,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _TabItem(
            label: AppLocalizations.t(context, 'wardrobe_all'),
            n: totalCount,
            selected: selectedId == 'all',
            onTap: () => onSelect('all'),
            color: context.fAccent,
            emoji: '✦',
          ),
          ...categories.map((c) => _TabItem(
            label: c.label,
            n: 0,
            selected: selectedId == c.id,
            onTap: () => onSelect(c.id),
            color: c.color,
            emoji: c.emoji,
          )),
          const SizedBox(width: 8),
          _AddTypeBtn(onAdd: onAddType),
        ],
      ),
    );
  }
}
class _TabItem extends StatelessWidget {
  final String label;
  final int n;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final String emoji;
  const _TabItem({required this.label, required this.n, required this.selected, required this.onTap, required this.color, required this.emoji});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : Colors.white12,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.7) : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : context.fTextSoft,
              ),
            ),
            if (n > 0) ...[
              const SizedBox(width: 4),
              Text('$n', style: TextStyle(fontSize: 11, color: selected ? Colors.white60 : context.fMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
class _AddTypeBtn extends StatelessWidget {
  final Function(WorkoutCategory) onAdd;
  const _AddTypeBtn({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddTypeDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF9B7FD4).withValues(alpha: 0.38), style: BorderStyle.solid),
        ),
        child: Text(AppLocalizations.t(context, 'fitness_add_type'), style: const TextStyle(fontSize: 13, color: Color(0xFF9B7FD4))),
      ),
    );
  }

  void _showAddTypeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '🏃');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.fSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.t(context, 'fitness_add_workout_type'), style: TextStyle(color: ctx.fText, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: ctx.fText),
              decoration: InputDecoration(
                hintText: AppLocalizations.t(context, 'fitness_eg_swimming'),
                hintStyle: TextStyle(color: ctx.fMuted),
                filled: true,
                fillColor: ctx.fCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                labelText: AppLocalizations.t(context, 'fitness_type_name'),
                labelStyle: TextStyle(color: ctx.fMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              style: TextStyle(color: ctx.fText, fontSize: 22),
              decoration: InputDecoration(
                hintText: '🏃',
                filled: true,
                fillColor: ctx.fCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                labelText: AppLocalizations.t(context, 'fitness_emoji'),
                labelStyle: TextStyle(color: ctx.fMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'common_cancel'), style: TextStyle(color: ctx.fMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final colors = [
                  const Color(0xE6A8D4F0), const Color(0xE6C8B0F5),
                  const Color(0xD9F5C842), const Color(0xE6F068B0),
                  const Color(0xE6A8F0C8), const Color(0xE6F0A8C8),
                ];
                final color = colors[name.hashCode.abs() % colors.length];
                final newType = WorkoutCategory(
                  id: name.toLowerCase().replaceAll(' ', '_'),
                  label: name,
                  emoji: emojiController.text.trim().isEmpty ? '🏋️' : emojiController.text.trim(),
                  color: color,
                  accent: Colors.black,
                );
                onAdd(newType);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.fAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.t(context, 'fitness_add')),
          ),
        ],
      ),
    );
  }
}
class _OutfitCard extends StatelessWidget {
  final WorkoutOutfit outfit;
  final WorkoutCategory category;
  final VoidCallback onDelete;
  const _OutfitCard({required this.outfit, required this.category, required this.onDelete});

  // Navy blue color palette — outfit section card కోసం
  List<Color> _palette() {
    return const [
      kNavyDeep,    // darkest navy
      kNavyMid,     // mid navy blue
      kNavyBright,  // vivid navy/royal blue
      kNavyLight,   // lighter accent blue
      kNavySoft,    // soft sky-navy highlight
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette();
    return Container(
      decoration: BoxDecoration(
        // Page bg (0xFF0F0F18) కి match అయ్యే deep navy gradient glass
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D1428).withValues(alpha: 0.92), // deep navy — page bg shade
            const Color(0xFF111830).withValues(alpha: 0.95), // slightly lighter navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kNavyBright.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          // Deep navy glow — page bg తో blend అవుతుంది
          BoxShadow(
            color: kNavyMid.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0A1020).withValues(alpha: 0.6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              // Image section
              Expanded(
                child: outfit.mainImage != null
                    ? Image.network(outfit.mainImage!, fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        decoration: BoxDecoration(
                          // No image — navy gradient placeholder (page bg తో match)
                          gradient: LinearGradient(
                            colors: [
                              kNavyMid.withValues(alpha: 0.7),
                              kNavyDeep.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(category.emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Container(
                                width: 28,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: kNavyLight.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // Bottom info section — page bg dark navy
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1020).withValues(alpha: 0.97),
                  border: Border(
                    top: BorderSide(color: kNavyBright.withValues(alpha: 0.22), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Outfit name
                    Text(
                      outfit.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.fText,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Category emoji pill — navy tint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kNavyMid.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: kNavyLight.withValues(alpha: 0.45), width: 1),
                      ),
                      child: Text(
                        '${category.emoji} ${category.label}',
                        style: const TextStyle(
                          fontSize: 8,
                          color: kNavySoft,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Color Palette Strip
                    Row(
                      children: [
                        Text(
                          'PALETTE',
                          style: TextStyle(
                            fontSize: 7,
                            color: kNavySoft.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: palette.asMap().entries.map((e) {
                                final isFirst = e.key == 0;
                                final isLast = e.key == palette.length - 1;
                                return Expanded(
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: e.value,
                                      borderRadius: BorderRadius.horizontal(
                                        left: isFirst ? const Radius.circular(4) : Radius.zero,
                                        right: isLast ? const Radius.circular(4) : Radius.zero,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Delete button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: kNavyDeep.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: kNavyLight.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.close, color: kNavySoft, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _EmptyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✦', style: TextStyle(fontSize: 40, color: context.fMuted.withValues(alpha: 0.3))),
          const SizedBox(height: 12),
          Text(AppLocalizations.t(context, 'fitness_no_routines'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.fText.withValues(alpha: 0.7))),
          Text(AppLocalizations.t(context, 'fitness_add_routine_hint'), style: TextStyle(fontSize: 13, color: context.fMuted)),
        ],
      ),
    );
  }
}
class _AddOutfitSheet extends StatefulWidget {
  final Function(WorkoutOutfit) onSave;
  final List<WorkoutCategory> categories;
  const _AddOutfitSheet({required this.onSave, required this.categories});
  @override
  State<_AddOutfitSheet> createState() => _AddOutfitSheetState();
}
class _AddOutfitSheetState extends State<_AddOutfitSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _itemInpController = TextEditingController();
  String _selectedCatId = '';
  final List<String> _items = [];
  final List<String> _images = [];
  @override
  void initState() {
    super.initState();
    _selectedCatId = widget.categories.first.id;
  }
  void _addItem() {
    final val = _itemInpController.text.trim();
    if (val.isNotEmpty) {
      setState(() {
        _items.add(val);
        _itemInpController.clear();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Page bg కి match — theme aware
        gradient: context.fPageBgGrad,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.t(context, 'fitness_new_routine'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.fText),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: context.fPanel,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.fBorder),
                      ),
                      child: Icon(Icons.close, color: context.fMuted, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Outfit Name ─────────────────────────────────────────────────
              _Label(AppLocalizations.t(context, 'fitness_routine_name')),
              TextField(
                controller: _nameController,
                style: TextStyle(color: context.fText, fontSize: 14),
                decoration: _fieldDeco('e.g. Sunday Morning Run'),
              ),
              const SizedBox(height: 20),

              // ── Workout Type ────────────────────────────────────────────────
              _Label(AppLocalizations.t(context, 'fitness_workout_type')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((c) => _CatPill(
                  cat: c,
                  selected: _selectedCatId == c.id,
                  onTap: () => setState(() => _selectedCatId = c.id),
                )).toList(),
              ),
              const SizedBox(height: 20),

              // ── Outfit Photos ───────────────────────────────────────────────
              _Label(AppLocalizations.t(context, 'fitness_routine_photos')),
              if (_images.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (ctx, i) => _PhotoSlot(
                      src: _images[i],
                      isMain: i == 0,
                      onDelete: () => setState(() => _images.removeAt(i)),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(child: _PhotoActionBtn(icon: Icons.camera_alt, label: AppLocalizations.t(context, 'fitness_camera'), onTap: _openCamera)),
                  const SizedBox(width: 8),
                  Expanded(child: _PhotoActionBtn(icon: Icons.grid_view_rounded, label: AppLocalizations.t(context, 'fitness_gallery'), onTap: _openGallery)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Clothing Items ──────────────────────────────────────────────
              _Label(AppLocalizations.t(context, 'fitness_clothing_items')),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemInpController,
                      style: TextStyle(color: context.fText, fontSize: 14),
                      decoration: _fieldDeco('e.g. Lightweight tank top'),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addItem,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.fAccent2, context.fAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.fAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _items.asMap().entries.map((e) => Chip(
                      label: Text(e.value, style: TextStyle(fontSize: 12, color: context.fText)),
                      onDeleted: () => setState(() => _items.removeAt(e.key)),
                      backgroundColor: context.fCard,
                      deleteIconColor: context.fMuted,
                      side: BorderSide(color: context.fBorder),
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Notes ───────────────────────────────────────────────────────
              _Label(AppLocalizations.t(context, 'wardrobe_notes')),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: context.fText, fontSize: 14),
                decoration: _fieldDeco('e.g. Great for hot weather...'),
              ),
              const SizedBox(height: 24),

              // ── Save Button ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isEmpty) return;
                    widget.onSave(WorkoutOutfit(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text,
                      catId: _selectedCatId,
                      items: _items,
                      notes: _notesController.text,
                      images: _images,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocalizations.t(context, 'fitness_save_routine'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
  InputDecoration _fieldDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.fMuted.withValues(alpha: 0.65), fontSize: 13),
    filled: true,
    fillColor: context.fCard,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.fBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.fAccent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
  final ImagePicker _picker = ImagePicker();

  Future<void> _openCamera() async {
    if (_images.length >= 6) return;
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (photo != null) {
        setState(() => _images.add(photo.path));
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _openGallery() async {
    if (_images.length >= 6) return;
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked.isNotEmpty) {
        setState(() {
          final remaining = 6 - _images.length;
          _images.addAll(
            picked.take(remaining).map((f) => f.path),
          );
        });
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }
}
class _PhotoSlot extends StatelessWidget {
  final String src;
  final bool isMain;
  final VoidCallback onDelete;
  const _PhotoSlot({required this.src, required this.isMain, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white10),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          src.startsWith('http')
              ? Image.network(src, fit: BoxFit.cover, width: 100, height: 100)
              : Image.file(File(src), fit: BoxFit.cover, width: 100, height: 100),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
          if (isMain)
            Positioned(
              bottom: 4, left: 4,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: const Text('MAIN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
            ),
        ],
      ),
    );
  }
}
class _PhotoActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PhotoActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.fPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.fAccent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: context.fAccent),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.fAccent)),
          ],
        ),
      ),
    );
  }
}
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: context.fAccent)),
    );
  }
}
class _CatPill extends StatelessWidget {
  final WorkoutCategory cat;
  final bool selected;
  final VoidCallback onTap;
  const _CatPill({required this.cat, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.fAccent.withValues(alpha: 0.18) : context.fPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.fAccent : context.fBorder,
            width: selected ? 1.5 : 1,
          ),

        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(height: 6),
            Text(cat.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? context.fText : context.fMuted)),
          ],
        ),
      ),
    );
  }
}

class _FitnessLensSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: kAccent.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.15), blurRadius: 48, offset: const Offset(0, -12))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9), border: Border.all(color: kAccent.withValues(alpha: 0.25))),
                    child: Icon(Icons.search, color: kAccent, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.t(context, 'fitness_ahvi_lens'), style: TextStyle(color: context.fText, fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kAccent.withValues(alpha: 0.08), border: Border.all(color: kAccent.withValues(alpha: 0.20))),
                    child: Icon(Icons.close, color: context.fMuted, size: 14),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kGlassBgStrong, border: Border.all(color: kAccent.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 2), color: kAccent.withValues(alpha: 0.08)),
                child: Icon(Icons.circle, color: kAccent, size: 12),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.t(context, 'fitness_visual_outfit_search'), style: TextStyle(color: context.fText, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppLocalizations.t(context, 'fitness_lens_desc'), style: TextStyle(color: context.fMuted, fontSize: 11.5, height: 1.5)),
              ])),
            ]),
          ),
          _FitnessLensTile(icon: Icons.search, name: 'Find Similar', desc: 'Discover similar outfits with shopping links', onTap: () => Navigator.pop(context)),
          _FitnessLensTile(icon: Icons.add_photo_alternate_outlined, name: 'Add to Wardrobe', desc: 'Save to your outfit collection', onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _FitnessLensTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String desc;
  final VoidCallback onTap;
  const _FitnessLensTile({required this.icon, required this.name, required this.desc, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kGlassBgStrong, borderRadius: BorderRadius.circular(16), border: Border.all(color: kAccent.withValues(alpha: 0.12))),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccent.withValues(alpha: 0.25))),
            child: Icon(icon, color: kAccent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: context.fText, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(desc, style: TextStyle(color: context.fMuted, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: context.fMuted, size: 20),
        ]),
      ),
    );
  }
}