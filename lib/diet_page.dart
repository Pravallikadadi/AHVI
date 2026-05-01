import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/app_localizations.dart';
import 'package:http/http.dart' as http;
// theme_tokens.dart — use package import below if in a sub-folder
// Update this path to match your project structure, e.g.:
// import 'package:your_app/theme/theme_tokens.dart';
import 'theme/theme_tokens.dart';
import 'package:myapp/widgets/ahvi_stylist_chat.dart';

// ─── THEME COLORS ────────────────────────────────────────────────────────────
// NOTE: kAccent and meal-type colors remain constant (not theme-dependent)
const Color kAccent = Color(0xFF7B6EF6);
// ─── THEME HELPERS ───────────────────────────────────────────────────────────
// Use these in build() methods instead of old hardcoded constants
extension DietTheme on BuildContext {
  AppThemeTokens get _t => Theme.of(this).extension<AppThemeTokens>()!;
  Color get dBg => _t.backgroundPrimary;
  Color get dText => _t.textPrimary;
  Color get dText2 => _t.textPrimary.withValues(alpha: 0.85);
  Color get dMuted => _t.mutedText;
  Color get dSurface => _t.backgroundSecondary;
  Color get dSurface2 => _t.card;
  Color get dBorder => _t.cardBorder;
  Color get dPanel => _t.panel;
  Color get dPanelBorder => _t.panelBorder;
  Color get dAccent => _t.accent.primary;
  Color get dAccent2 => _t.accent.secondary;
  Color get dSnackBg => _t.backgroundPrimary.computeLuminance() > 0.5
      ? const Color(0xFF1C1C1E)
      : const Color(0xFF2C2C2E);
}

const Color kBreakfastFg = Color(0xFFB85500);
const Color kBreakfastBg = Color(0xFFFFF4EE);
const Color kLunchFg = Color(0xFF1A7A35);
const Color kLunchBg = Color(0xFFF0FAF2);
const Color kDinnerFg = Color(0xFF3634A3);
const Color kDinnerBg = Color(0xFFF0F0FD);
const Color kSnackFg = Color(0xFFB8003A);
const Color kSnackBg = Color(0xFFFFF0F5);
// ─── DATA MODELS ─────────────────────────────────────────────────────────────
class Meal {
  String type;
  String name;
  String desc;
  int cal;
  int protein;
  int carbs;
  int fat;
  String cls;
  String icon;
  String? imagePath; // Local path or URL
  Meal({
    required this.type,
    required this.name,
    required this.desc,
    required this.cal,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    required this.cls,
    this.icon = '',
    this.imagePath,
  });
  Meal copyWith({String? type, String? name, String? desc, int? cal, int? protein, int? carbs, int? fat, String? imagePath}) {
    return Meal(
      type: type ?? this.type,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      cal: cal ?? this.cal,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      cls: cls,
      icon: icon,
      imagePath: imagePath ?? this.imagePath,
    );
  }
  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'desc': desc,
        'cal': cal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'cls': cls,
        'icon': icon,
        'imagePath': imagePath,
      };
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        type: j['type'] ?? '',
        name: j['name'] ?? '',
        desc: j['desc'] ?? '',
        cal: j['cal'] ?? 0,
        protein: j['protein'] ?? 0,
        carbs: j['carbs'] ?? 0,
        fat: j['fat'] ?? 0,
        cls: j['cls'] ?? '',
        icon: j['icon'] ?? '',
        imagePath: j['imagePath'],
      );
}
class DayPlan {
  final String label; // e.g. "Monday" or "Week 1"
  final List<Meal> meals;
  DayPlan({required this.label, required this.meals});
}
class MealPlan {
  int id;
  String name;
  String desc;
  String planType; // daily / weekly / monthly
  List<Meal> meals; // used for daily
  List<DayPlan> days; // used for weekly (7) / monthly (4)
  MealPlan({
    required this.id,
    required this.name,
    required this.desc,
    required this.planType,
    required this.meals,
    this.days = const [],
  });
  int get totalCal => planType == 'daily'
      ? meals.fold(0, (a, m) => a + m.cal)
      : days.fold(0, (a, d) => a + d.meals.fold(0, (b, m) => b + m.cal));
  int get totalProtein => planType == 'daily'
      ? meals.fold(0, (a, m) => a + m.protein)
      : days.fold(0, (a, d) => a + d.meals.fold(0, (b, m) => b + m.protein));
  MealPlan copyWith({String? name, String? desc, String? planType, List<Meal>? meals, List<DayPlan>? days}) {
    return MealPlan(
      id: id,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      planType: planType ?? this.planType,
      meals: meals ?? this.meals,
      days: days ?? this.days,
    );
  }
}
class ChatMessage {
  final String text;
  final bool isBot;
  MealPlan? plan;
  ChatMessage({required this.text, required this.isBot, this.plan});
}
// ─── IMAGE PROVIDER (TheMealDB → Wikipedia → Pexels) ────────────────────────
//
// API Key Setup:
//   1. https://www.pexels.com/api/ lo free account create cheyyi
//   2. Dashboard lo API key copy cheyyi
//   3. Below '_kPexelsApiKey' lo paste cheyyi
//
// Free tier: 200 requests/hour, 20,000/month — production ki sufficient
// ─────────────────────────────────────────────────────────────────────────────
class MealImageProvider {
  static const String _kPexelsApiKey = 'b48yMGltJ1JDONmzdmpyLEhtZSIQnVZv0Mg73adF8ifAjZj9jJlGNBev'; // 👈 replace cheyyi

  static final Map<String, String?> _cache = {};

  // Emoji prefix clean cheyyadaniki
  static String _cleanQuery(String raw) {
    return raw
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '')
        .trim();
  }

  static Future<String?> fetchImage(String mealName) async {
    final query = mealName.toLowerCase().trim();
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    final clean = _cleanQuery(query);
    final shortQuery = clean.split(' ').take(3).join(' ');

    // ── Tier 1: TheMealDB (Western dishes — no API key, fast) ──────────────
    try {
      final encoded = Uri.encodeComponent(clean.split(' ').take(2).join(' '));
      final res = await http.get(
        Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=$encoded'),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final thumb = data['meals']?[0]?['strMealThumb'] as String?;
        if (thumb != null) {
          _cache[query] = thumb;
          return thumb;
        }
      }
    } catch (_) {}

    // ── Tier 2: Wikipedia Summary API (Indian dishes baguntayi) ────────────
    try {
      final wikiEncoded = Uri.encodeComponent(shortQuery);
      final res = await http.get(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$wikiEncoded'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final imgUrl = data['thumbnail']?['source'] ?? data['originalimage']?['source'];
        if (imgUrl != null) {
          final sized = (imgUrl as String).replaceFirst(RegExp(r'/\d+px-'), '/480px-');
          _cache[query] = sized;
          return sized;
        }
      }
    } catch (_) {}

    // ── Tier 3: Pexels API (production-grade, reliable fallback) ───────────
    if (_kPexelsApiKey != 'b48yMGltJ1JDONmzdmpyLEhtZSIQnVZv0Mg73adF8ifAjZj9jJlGNBev') {
      try {
        final pexelsQuery = Uri.encodeComponent('$shortQuery food');
        final res = await http.get(
          Uri.parse('https://api.pexels.com/v1/search?query=$pexelsQuery&per_page=1&orientation=square'),
          headers: {'Authorization': _kPexelsApiKey},
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final imgUrl = data['photos']?[0]?['src']?['medium'] as String?;
          if (imgUrl != null) {
            _cache[query] = imgUrl;
            return imgUrl;
          }
        }
      } catch (_) {}
    }

    // Nothing found — null cache chestuundi so next session retry avutuundi
    _cache[query] = null;
    return null;
  }
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  final List<MealPlan> _plans = [];
  final _plansMessengerKey = GlobalKey<ScaffoldMessengerState>();

  void _showSnack(SnackBar snack) {
    _plansMessengerKey.currentState?.showSnackBar(snack);
  }

  void _addPlan(MealPlan p) {
    setState(() {
      _plans.add(MealPlan(
        id: DateTime.now().millisecondsSinceEpoch,
        name: p.name,
        desc: p.desc,
        planType: p.planType,
        meals: List.from(p.meals),
      ));
    });
  }
  void _savePlanFromChat(MealPlan p) {
    final plan = MealPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      name: p.name,
      desc: p.desc,
      planType: p.planType,
      meals: List.from(p.meals),
    );
    setState(() => _plans.add(plan));
    _showSnack(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('"${plan.name}" ${AppLocalizations.t(context, 'diet_saved_to_plans')}', style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      backgroundColor: context.dSnackBg,
      duration: const Duration(seconds: 2),
    ));
  }
  void _deletePlan(int id) {
    setState(() => _plans.removeWhere((p) => p.id == id));
  }
  void _editPlan(MealPlan updated) {
    setState(() {
      final idx = _plans.indexWhere((p) => p.id == updated.id);
      if (idx != -1) _plans[idx] = updated;
    });
    _showSnack(SnackBar(
      content: Row(children: [
        const Icon(Icons.edit_note_rounded, color: Color(0xFFFFD60A), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('"${updated.name}" ${AppLocalizations.t(context, 'diet_updated_successfully')}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
      ]),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      backgroundColor: context.dSnackBg,
      duration: const Duration(seconds: 2),
    ));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dBg,
      body: Stack(
        children: [
          PlansScreen(
            plans: _plans,
            onAdd: _addPlan,
            onDelete: _deletePlan,
            onEdit: _editPlan,
            messengerKey: _plansMessengerKey,
          ),
          Positioned(
            bottom: 30, right: 20,
            child: _AskAhviFab(
              onTap: () => showAhviStylistChatSheet(context, moduleContext: 'diet'),
            ),
          ),
        ],
      ),
    );
  }
}
// ─── PLANS SCREEN ─────────────────────────────────────────────────────────────
class PlansScreen extends StatefulWidget {
  final List<MealPlan> plans;
  final ValueChanged<MealPlan> onAdd;
  final ValueChanged<int> onDelete;
  final ValueChanged<MealPlan> onEdit;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const PlansScreen({super.key, required this.plans, required this.onAdd, required this.onDelete, required this.onEdit, required this.messengerKey});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}
class _PlansScreenState extends State<PlansScreen> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = _filter == 'all' ? widget.plans : widget.plans.where((p) => p.planType == _filter).toList();
    return ScaffoldMessenger(
      key: widget.messengerKey,
      child: Scaffold(
      backgroundColor: context.dBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── PAGE HEADER ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diet',
                        style: GoogleFonts.anton(fontSize: 22, color: Colors.black, letterSpacing: 0.5),
                      ),

                    ],
                  ),
                ],
              ),
            ),
            // ─────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showAddModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9B8FFF), Color(0xFF7B6EF6), Color(0xFF5B8DEF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: const [
                          BoxShadow(color: Color(0x557B6EF6), blurRadius: 18, offset: Offset(0, 5)),
                          BoxShadow(color: Color(0x225B8DEF), blurRadius: 30, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 7),
                          Text(AppLocalizations.t(context, 'diet_add_custom_meal'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FilterTabs(selected: _filter, onSelect: (v) => setState(() => _filter = v)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.plans.isEmpty
                  ? _emptyState(false)
                  : filtered.isEmpty
                      ? _emptyState(true)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => PlanCard(
                            plan: filtered[i],
                            onDelete: () => widget.onDelete(filtered[i].id),
                            onEdit: () => _showEditModal(context, filtered[i]),
                            messengerKey: widget.messengerKey,
                          ),
                        ),
            ),
          ],
        ),
      ),
    ));
  }
  Widget _emptyState(bool isFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isFilter ? '🔍' : '🥗', style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          Text(
            isFilter ? AppLocalizations.t(context, 'diet_no_filter') : AppLocalizations.t(context, 'diet_no_plans'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.dMuted, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
  void _showAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddMealModal(messengerKey: widget.messengerKey, onSave: (plan) {
        widget.onAdd(plan);
        Navigator.pop(ctx);
      }),
    );
  }
  void _showEditModal(BuildContext context, MealPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditMealModal(
        plan: plan,
        messengerKey: widget.messengerKey,
        onSave: (updated) {
          widget.onEdit(updated);
          Navigator.pop(ctx);
        },
      ),
    );
  }
  String _weekday(int d) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}
// ─── CHIP STYLE CONFIG ────────────────────────────────────────────────────────
class _ChipStyle {
  final Color pastelBg;
  final Color pastelBorder;
  final Color textColor;
  const _ChipStyle({required this.pastelBg, required this.pastelBorder, required this.textColor});
}

class _FilterTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _FilterTabs({required this.selected, required this.onSelect});

  static const Map<String, _ChipStyle> _styles = {
    'all':     _ChipStyle(pastelBg: Color(0xFFEDE9FF), pastelBorder: Color(0xFFBDB4FF), textColor: Color(0xFF5A4FCF)),
    'daily':   _ChipStyle(pastelBg: Color(0xFFFFF4DD), pastelBorder: Color(0xFFFFD980), textColor: Color(0xFFB07700)),
    'weekly':  _ChipStyle(pastelBg: Color(0xFFE5F7F0), pastelBorder: Color(0xFF86D9B5), textColor: Color(0xFF1A7A50)),
    'monthly': _ChipStyle(pastelBg: Color(0xFFFFE8F2), pastelBorder: Color(0xFFFFADD4), textColor: Color(0xFFB0005A)),
  };

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('all', '⊞', AppLocalizations.t(context, 'diet_all_plans')),
      ('daily', '☀️', AppLocalizations.t(context, 'diet_filter_daily')),
      ('weekly', '📅', AppLocalizations.t(context, 'diet_filter_weekly')),
      ('monthly', '📆', AppLocalizations.t(context, 'diet_filter_monthly')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final active = selected == t.$1;
          final style = _styles[t.$1]!;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? style.pastelBg : context.dSurface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: active ? style.pastelBorder : context.dBorder,
                    width: active ? 1.5 : 1.0,
                  ),
                  boxShadow: [],
                ),
                child: Row(
                  children: [
                    Text(t.$2, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      t.$3,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? style.textColor : context.dText2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
class _MealRow extends StatelessWidget {
  final Meal m;
  const _MealRow({required this.m});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dBorder))),
      child: Row(
        children: [
          _MealImage(imagePath: m.imagePath, emoji: m.icon),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(m.type, style: TextStyle(fontSize: 10, color: context.dMuted, fontWeight: FontWeight.w500)),
          ])),
          Text('${m.cal} cal', style: TextStyle(fontSize: 12, color: context.dMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
class PlanCard extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onDelete;
  final bool isSuggestion;
  final ValueChanged<MealPlan>? onSave;
  final VoidCallback? onEdit;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  const PlanCard({super.key, required this.plan, required this.onDelete, this.isSuggestion = false, this.onSave, this.onEdit, this.messengerKey});

  void _showToast(BuildContext context, {required IconData icon, required Color iconColor, required String message}) {
    final messenger = messengerKey?.currentState ?? ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
      ]),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      backgroundColor: context.dSnackBg,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final type = plan.planType.toLowerCase();
    final isWeekly = type == 'weekly';
    final isMonthly = type == 'monthly';
    final Color topBgStart = isWeekly ? const Color(0xFFB2E0D8) : (isMonthly ? const Color(0xFFB8D4F5) : const Color(0xFFF7C5C5));
    final Color topBgEnd = isWeekly ? const Color(0xFFC8EED6) : (isMonthly ? const Color(0xFFC8C8F8) : const Color(0xFFF9D8C8));
    final Color titleColor = isWeekly ? const Color(0xFF164A38) : (isMonthly ? const Color(0xFF1A2E6A) : const Color(0xFF7A2020));
    final Color typePillColor = isWeekly ? const Color(0xFF2A6E5E) : (isMonthly ? const Color(0xFF2A4A8A) : const Color(0xFFA04040));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.dSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [topBgStart, topBgEnd])),
            child: Row(
              children: [
                Expanded(child: Text(plan.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: 0.9))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(100)),
                  child: Text(type.toUpperCase(), style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: typePillColor)),
                ),
                const SizedBox(width: 8),
                if (!isSuggestion) ...[
                  GestureDetector(
                    onTap: () {
                      _showToast(context,
                        icon: Icons.edit_note_rounded,
                        iconColor: const Color(0xFFFFD60A),
                        message: '${AppLocalizations.t(context, 'diet_editing')} "${plan.name}"...',
                      );
                      onEdit?.call();
                    },
                    child: Icon(Icons.edit_outlined, size: 18, color: typePillColor.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: ctx.dSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(AppLocalizations.t(context, 'diet_delete_plan'), style: TextStyle(color: ctx.dText, fontWeight: FontWeight.w700, fontSize: 16)),
                          content: Text(AppLocalizations.t(context, 'diet_delete_confirm').replaceAll('{name}', plan.name), style: TextStyle(color: ctx.dMuted, fontSize: 13, height: 1.5)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppLocalizations.t(context, 'common_cancel'), style: TextStyle(color: ctx.dMuted, fontWeight: FontWeight.w600)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showToast(context,
                                  icon: Icons.delete_forever_rounded,
                                  iconColor: const Color(0xFFFF453A),
                                  message: '"${plan.name}" deleted!',
                                );
                                onDelete();
                              },
                              child: Text(AppLocalizations.t(context, 'common_delete'), style: const TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(Icons.delete_sweep_outlined, size: 18, color: typePillColor.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
          if (plan.planType == 'daily')
            ...plan.meals.map((m) => _MealRow(m: m))
          else
            ...plan.days.map((day) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: typePillColor.withValues(alpha: 0.08),
                  child: Text(day.label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: typePillColor, letterSpacing: 0.7)),
                ),
                ...day.meals.map((m) => _MealRow(m: m)),
              ],
            )),
          if (isSuggestion)
            Container(
              padding: const EdgeInsets.all(10),
              color: context.dSurface2,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: context.dSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.dAccent.withValues(alpha: 0.5))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.edit_outlined, size: 13, color: context.dAccent),
                          SizedBox(width: 5),
                          Text(AppLocalizations.t(context, 'common_edit'), style: TextStyle(color: context.dAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => onSave?.call(plan),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: context.dAccent, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(AppLocalizations.t(context, 'diet_save_suggestion'), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              color: context.dSurface2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${AppLocalizations.t(context, 'diet_total')}: ${plan.totalCal} ${AppLocalizations.t(context, 'diet_cal')}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: titleColor)),
                ],
              ),
            )
        ],
      ),
    );
  }
}
class AddMealModal extends StatefulWidget {
  final ValueChanged<MealPlan> onSave;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const AddMealModal({super.key, required this.onSave, required this.messengerKey});
  @override
  State<AddMealModal> createState() => _AddMealModalState();
}
class _AddMealModalState extends State<AddMealModal> {
  final _nameCtrl = TextEditingController();
  final String _planType = 'daily';
  bool _isSaved = false;
  final _bNameCtrl = TextEditingController(), _lNameCtrl = TextEditingController(), _dNameCtrl = TextEditingController(), _sNameCtrl = TextEditingController();
  final _bCalCtrl = TextEditingController(), _lCalCtrl = TextEditingController(), _dCalCtrl = TextEditingController(), _sCalCtrl = TextEditingController();
  String? _bImg, _lImg, _dImg, _sImg;

  // Local messenger key — toasts appear INSIDE the modal, not behind it
  final _localKey = GlobalKey<ScaffoldMessengerState>();

  void _toast({required IconData icon, required Color iconColor, required String msg}) {
    _localKey.currentState?.clearSnackBars();
    _localKey.currentState?.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
      ]),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      backgroundColor: context.dSnackBg,
      duration: const Duration(seconds: 2),
    ));
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFFFD60A), msg: AppLocalizations.t(context, 'diet_enter_plan_name'));
      return;
    }
    final meals = <Meal>[];
    void add(String type, String cls, String icon, TextEditingController n, TextEditingController c, String? img) {
      if (n.text.trim().isNotEmpty) meals.add(Meal(type: type, cls: cls, icon: icon, name: n.text.trim(), desc: '', cal: int.tryParse(c.text.trim()) ?? 0, imagePath: img));
    }
    add('Breakfast', 'breakfast', '🌅', _bNameCtrl, _bCalCtrl, _bImg);
    add('Lunch', 'lunch', '☀️', _lNameCtrl, _lCalCtrl, _lImg);
    add('Dinner', 'dinner', '🌙', _dNameCtrl, _dCalCtrl, _dImg);
    add('Snack', 'snack', '🍎', _sNameCtrl, _sCalCtrl, _sImg);
    if (meals.isEmpty) {
      _toast(icon: Icons.restaurant_outlined, iconColor: const Color(0xFFFF9F0A), msg: AppLocalizations.t(context, 'diet_add_meal_entry'));
      return;
    }
    setState(() => _isSaved = true);
    widget.onSave(MealPlan(id: 0, name: name, desc: '', planType: _planType, meals: meals));
    _toast(icon: Icons.check_circle, iconColor: const Color(0xFF30D158), msg: '"$name" plan saved successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _localKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, sc) {
            return Container(
              decoration: BoxDecoration(
                color: context.dSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dBorder))),
                    child: Row(children: [
                      Expanded(child: Text(AppLocalizations.t(context, 'diet_add_custom_meal_plan'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 20)),
                    ]),
                  ),
                  // Scrollable body
                  Expanded(
                    child: ListView(
                      controller: sc,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(AppLocalizations.t(context, 'diet_plan_name'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.t(context, 'diet_plan_hint'),
                            filled: true,
                            fillColor: context.dSurface2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.dBorder, width: 1.5)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.dBorder, width: 1.5)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.dAccent, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(AppLocalizations.t(context, 'diet_plan_type'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(color: context.dAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dAccent)),
                          child: Center(child: Text(AppLocalizations.t(context, 'diet_daily'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dAccent))),
                        ),
                        const SizedBox(height: 24),
                        Text(AppLocalizations.t(context, 'diet_meals'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 12),
                        _MealEntry(label: AppLocalizations.t(context, 'diet_breakfast'), emoji: '🌅', color: kBreakfastFg, bg: kBreakfastBg, nameCtrl: _bNameCtrl, calCtrl: _bCalCtrl, imagePath: _bImg, onImageChanged: (v) => setState(() => _bImg = v)),
                        _MealEntry(label: AppLocalizations.t(context, 'diet_lunch'),     emoji: '☀️', color: kLunchFg,     bg: kLunchBg,     nameCtrl: _lNameCtrl, calCtrl: _lCalCtrl, imagePath: _lImg, onImageChanged: (v) => setState(() => _lImg = v)),
                        _MealEntry(label: AppLocalizations.t(context, 'diet_dinner'),    emoji: '🌙', color: kDinnerFg,    bg: kDinnerBg,    nameCtrl: _dNameCtrl, calCtrl: _dCalCtrl, imagePath: _dImg, onImageChanged: (v) => setState(() => _dImg = v)),
                        _MealEntry(label: AppLocalizations.t(context, 'diet_snack'),     emoji: '🍎', color: kSnackFg,     bg: kSnackBg,     nameCtrl: _sNameCtrl, calCtrl: _sCalCtrl, imagePath: _sImg, onImageChanged: (v) => setState(() => _sImg = v)),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: _isSaved ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isSaved ? const Color(0xFF1A7A35) : context.dAccent,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: (_isSaved ? const Color(0xFF1A7A35) : context.dAccent).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSaved) ...[
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(_isSaved ? AppLocalizations.t(context, 'diet_plan_saved') : AppLocalizations.t(context, 'diet_save_my_plan'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ], // ListView children
                    ), // ListView
                  ), // Expanded
                ], // Column children
              ), // Column
            ); // Container
          }, // builder
        ), // DraggableScrollableSheet
      ), // Scaffold
    ); // ScaffoldMessenger
  }
}
class _MealEntry extends StatefulWidget {
  final String label, emoji; final Color color, bg; final TextEditingController nameCtrl, calCtrl; final String? imagePath; final ValueChanged<String?> onImageChanged;
  const _MealEntry({required this.label, required this.emoji, required this.color, required this.bg, required this.nameCtrl, required this.calCtrl, required this.imagePath, required this.onImageChanged});
  @override
  State<_MealEntry> createState() => _MealEntryState();
}
class _MealEntryState extends State<_MealEntry> {
  bool _fetching = false;
  Future<void> _autoFetch() async {
    final name = widget.nameCtrl.text.trim(); if (name.isEmpty) return;
    setState(() => _fetching = true);
    final url = await MealImageProvider.fetchImage(name);
    if (mounted) {
      setState(() => _fetching = false);
      if (url != null) widget.onImageChanged(url);
    }
  }
  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(_onNameChanged);
  }
  String _lastFetched = '';
  void _onNameChanged() {
    final name = widget.nameCtrl.text.trim();
    if (name.length > 3) {
      Future.delayed(const Duration(milliseconds: 900), () {
        final current = widget.nameCtrl.text.trim();
        if (current == name && current != _lastFetched && mounted) {
          _lastFetched = current;
          _autoFetch();
        }
      });
    }
  }
  @override
  void dispose() {
    widget.nameCtrl.removeListener(_onNameChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.dSurface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.dBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(widget.emoji, style: const TextStyle(fontSize: 17)), const SizedBox(width: 8), Expanded(child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          GestureDetector(onTap: _fetching ? null : _autoFetch, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: context.dAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: _fetching ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.dAccent)) : Icon(Icons.auto_fix_high, size: 14, color: context.dAccent)))
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity, height: 90,
          decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.dBorder)),
          clipBehavior: Clip.antiAlias,
          child: widget.imagePath != null
            ? Stack(children: [
                Positioned.fill(child: _MealImage(imagePath: widget.imagePath, emoji: widget.emoji, size: 90)),
                Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => widget.onImageChanged(null), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))))
              ])
            : _fetching
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.dAccent)), SizedBox(height: 6), Text(AppLocalizations.t(context, 'diet_fetching_image'), style: TextStyle(fontSize: 10, color: context.dMuted))]))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(widget.emoji, style: const TextStyle(fontSize: 22)), const SizedBox(height: 4), Text(AppLocalizations.t(context, 'diet_type_name_hint'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: widget.color.withValues(alpha: 0.6)))]),
        ),
        const SizedBox(height: 12),
        TextField(controller: widget.nameCtrl, decoration: InputDecoration(hintText: AppLocalizations.t(context, 'diet_meal_name_hint'), filled: true, fillColor: context.dSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.dBorder)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: widget.calCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: AppLocalizations.t(context, 'diet_cal_hint'), suffixText: 'cal', filled: true, fillColor: context.dSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.dBorder)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class EditMealModal extends StatefulWidget {
  final MealPlan plan;
  final ValueChanged<MealPlan> onSave;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  const EditMealModal({super.key, required this.plan, required this.onSave, required this.messengerKey});
  @override
  State<EditMealModal> createState() => _EditMealModalState();
}
class _EditMealModalState extends State<EditMealModal> {
  late final TextEditingController _nameCtrl;
  late final Map<String, TextEditingController> _nameCtrlMap;
  late final Map<String, TextEditingController> _calCtrlMap;
  late final Map<String, String?> _imgMap;
  bool _isSaved = false;
  final _mealTypes = [
    ('Breakfast', 'breakfast', '🌅', kBreakfastFg, kBreakfastBg),
    ('Lunch', 'lunch', '☀️', kLunchFg, kLunchBg),
    ('Dinner', 'dinner', '🌙', kDinnerFg, kDinnerBg),
    ('Snack', 'snack', '🍎', kSnackFg, kSnackBg),
  ];

  // Local messenger key — toasts appear INSIDE the modal
  final _localKey = GlobalKey<ScaffoldMessengerState>();

  void _toast({required IconData icon, required Color iconColor, required String msg}) {
    _localKey.currentState?.clearSnackBars();
    _localKey.currentState?.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
      ]),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      backgroundColor: context.dSnackBg,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plan.name);
    _nameCtrlMap = {};
    _calCtrlMap = {};
    _imgMap = {};
    for (final mt in _mealTypes) {
      final existing = widget.plan.meals.where((m) => m.cls == mt.$2).firstOrNull;
      _nameCtrlMap[mt.$2] = TextEditingController(text: existing?.name ?? '');
      _calCtrlMap[mt.$2] = TextEditingController(text: existing != null && existing.cal > 0 ? '${existing.cal}' : '');
      _imgMap[mt.$2] = existing?.imagePath;
    }
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _nameCtrlMap.values) {
      c.dispose();
    }
    for (final c in _calCtrlMap.values) {
      c.dispose();
    }
    super.dispose();
  }
  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFFFD60A), msg: AppLocalizations.t(context, 'diet_enter_plan_name'));
      return;
    }
    final meals = <Meal>[];
    for (final mt in _mealTypes) {
      final n = _nameCtrlMap[mt.$2]!.text.trim();
      if (n.isNotEmpty) {
        meals.add(Meal(type: mt.$1, cls: mt.$2, icon: mt.$3, name: n, desc: '', cal: int.tryParse(_calCtrlMap[mt.$2]!.text.trim()) ?? 0, imagePath: _imgMap[mt.$2]));
      }
    }
    if (meals.isEmpty) {
      _toast(icon: Icons.restaurant_outlined, iconColor: const Color(0xFFFF9F0A), msg: AppLocalizations.t(context, 'diet_add_meal_entry'));
      return;
    }
    setState(() => _isSaved = true);
    widget.onSave(MealPlan(id: widget.plan.id, name: name, desc: widget.plan.desc, planType: widget.plan.planType, meals: meals));
    _toast(icon: Icons.check_circle, iconColor: const Color(0xFF30D158), msg: '"$name" updated successfully!');
  }
  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _localKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, sc) {
            return Container(
              decoration: BoxDecoration(
                color: context.dSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.dBorder))),
                    child: Row(children: [
                      Expanded(child: Text(AppLocalizations.t(context, 'diet_edit_meal_plan'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 20)),
                    ]),
                  ),
                  // Scrollable body
                  Expanded(
                    child: ListView(
                      controller: sc,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(AppLocalizations.t(context, 'diet_plan_name'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.t(context, 'diet_plan_hint'),
                            filled: true,
                            fillColor: context.dSurface2,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(AppLocalizations.t(context, 'diet_plan_type'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(color: context.dAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: context.dAccent)),
                          child: Center(child: Text(AppLocalizations.t(context, 'diet_daily'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dAccent))),
                        ),
                        const SizedBox(height: 24),
                        Text(AppLocalizations.t(context, 'diet_meals'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dMuted, letterSpacing: 0.8)),
                        const SizedBox(height: 12),
                        ...(_mealTypes.map((mt) => StatefulBuilder(
                          builder: (ctx, setSt) => _MealEntry(
                            label: mt.$1, emoji: mt.$3, color: mt.$4, bg: mt.$5,
                            nameCtrl: _nameCtrlMap[mt.$2]!,
                            calCtrl: _calCtrlMap[mt.$2]!,
                            imagePath: _imgMap[mt.$2],
                            onImageChanged: (v) { setSt(() => _imgMap[mt.$2] = v); setState(() {}); },
                          ),
                        ))),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: _isSaved ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isSaved ? const Color(0xFF1A7A35) : context.dAccent,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: (_isSaved ? const Color(0xFF1A7A35) : context.dAccent).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSaved) ...[
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(_isSaved ? 'Changes Saved!' : 'Save Changes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ], // ListView children
                    ), // ListView
                  ), // Expanded
                ], // Column children
              ), // Column
            ); // Container
          }, // builder
        ), // DraggableScrollableSheet
      ), // Scaffold
    ); // ScaffoldMessenger
  }
}
class _MealImage extends StatelessWidget {
  final String? imagePath; final String emoji; final double size;
  const _MealImage({this.imagePath, required this.emoji, this.size = 28});
  @override
  Widget build(BuildContext context) {
    if (imagePath == null) return SizedBox(width: size, height: size, child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.55))));
    if (!imagePath!.startsWith('http')) return SizedBox(width: size, height: size, child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.55))));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size, height: size,
        child: Image.network(
          imagePath!,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              color: context.dSurface2,
              child: Center(child: SizedBox(width: size * 0.35, height: size * 0.35, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.dAccent, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null))),
            );
          },
          errorBuilder: (_, _, _) => Container(color: context.dSurface2, child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5)))),
        ),
      ),
    );
  }
}

// ─── CHATGPT-STYLE PLUS BUTTON FOR DIET ─────────────────────────────────────
class _DietPlusButton extends StatefulWidget {
  final VoidCallback? onCameraSelected;
  const _DietPlusButton({this.onCameraSelected});
  @override
  State<_DietPlusButton> createState() => _DietPlusButtonState();
}

class _DietPlusButtonState extends State<_DietPlusButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;
  bool _menuOpen = false;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.125)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _closeMenu();
    _ctrl.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (_menuOpen) { _closeMenu(); return; }
    setState(() => _menuOpen = true);
    _ctrl.forward();
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final actions = [
      (Icons.camera_alt_outlined, 'Camera', const Color(0xFFFF6B6B)),
      (Icons.photo_library_outlined, 'Photos', const Color(0xFF4ECDC4)),
      (Icons.attach_file_rounded, 'Files', const Color(0xFF45B7D1)),
      (Icons.search_rounded, 'Search Food', const Color(0xFF96CEB4)),
    ];

    _overlay = OverlayEntry(builder: (_) {
      return GestureDetector(
        onTap: _closeMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(children: [
          Positioned(
            left: offset.dx - 10,
            bottom: MediaQuery.of(context).size.height - offset.dy + 8,
            child: GestureDetector(
              onTap: () {},
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.dSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.dBorder, width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: actions.map((a) => _DietMenuRow(
                      icon: a.$1,
                      label: a.$2,
                      color: a.$3,
                      onTap: () {
                        _closeMenu();
                        if (a.$2 == 'Camera' || a.$2 == 'Search Food') widget.onCameraSelected?.call();
                      },
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _closeMenu() {
    _overlay?.remove();
    _overlay = null;
    _ctrl.reverse();
    if (mounted) setState(() => _menuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMenu,
      child: AnimatedBuilder(
        animation: _rotateAnim,
        builder: (_, child) => Transform.rotate(
          angle: _rotateAnim.value * 2 * 3.14159,
          child: child,
        ),
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _menuOpen ? context.dAccent.withValues(alpha: 0.15) : context.dSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _menuOpen ? context.dAccent.withValues(alpha: 0.5) : context.dBorder, width: 1.5),
          ),
          child: Icon(Icons.add_rounded, color: context.dAccent, size: 20),
        ),
      ),
    );
  }
}

class _DietMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DietMenuRow({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  State<_DietMenuRow> createState() => _DietMenuRowState();
}

class _DietMenuRowState extends State<_DietMenuRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) { setState(() => _hovered = false); widget.onTap(); },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
            child: Icon(widget.icon, color: widget.color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(widget.label, style: TextStyle(color: context.dText, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── DIET LENS ACTION SHEET ──────────────────────────────────────────────────
class _DietLensActionSheet extends StatelessWidget {
  const _DietLensActionSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.dSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(color: context.dMuted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(99)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: Text(AppLocalizations.t(context, 'diet_visual_search'), style: TextStyle(color: context.dText, fontSize: 16, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.dSurface2, border: Border.all(color: context.dBorder)),
                  child: Icon(Icons.close, color: context.dMuted, size: 14),
                ),
              ),
            ]),
          ),
          // Info card
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.dSurface2, border: Border.all(color: context.dAccent.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.dAccent.withValues(alpha: 0.5), width: 2), color: context.dAccent.withValues(alpha: 0.08)),
                child: Icon(Icons.camera_alt_outlined, color: context.dAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.t(context, 'diet_visual_ai_search'), style: TextStyle(color: context.dText, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(AppLocalizations.t(context, 'diet_visual_ai_desc'), style: TextStyle(color: context.dMuted, fontSize: 11.5, height: 1.5)),
              ])),
            ]),
          ),
          _DietLensOptionTile(
            icon: Icons.search,
            name: 'Identify Food',
            desc: 'Scan food to get calories & nutrition',
            color: context.dAccent,
            onTap: () => Navigator.pop(context),
          ),
          _DietLensOptionTile(
            icon: Icons.add_photo_alternate_outlined,
            name: 'Add to Meal Plan',
            desc: 'Save scanned food to your plan',
            color: const Color(0xFF1A7A35),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _DietLensOptionTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  const _DietLensOptionTile({required this.icon, required this.name, required this.desc, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.dSurface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.dBorder)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: context.dText, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(desc, style: TextStyle(color: context.dMuted, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: context.dMuted, size: 20),
        ]),
      ),
    );
  }
}

// ─── DIET PULSING MIC ICON ───────────────────────────────────────────────────
class _DietPulsingMicIcon extends StatefulWidget {
  const _DietPulsingMicIcon();
  @override
  State<_DietPulsingMicIcon> createState() => _DietPulsingMicIconState();
}

class _DietPulsingMicIconState extends State<_DietPulsingMicIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18));
  }
}

// ─── ASK AHVI FAB (matches Skincare style exactly) ───────────────────────────
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
    final accent = context.dAccent;
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
              // Pulse ring
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