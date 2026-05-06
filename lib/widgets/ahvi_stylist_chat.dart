import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/widgets/ahvi_header.dart';
import 'package:myapp/diet_page.dart' as diet_page;
import 'package:myapp/fitness_page.dart' as fitness_page;
import 'package:myapp/skincare.dart' as skincare_page;
import 'package:myapp/services/backend_service.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/medi_tracker.dart' as medi_tracker_page;
import 'package:myapp/daily_wear.dart' as daily_wear_page;
import 'package:myapp/calendar.dart' as calendar_page;
import 'package:myapp/bills_page.dart' as bills_page;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';
import 'package:myapp/theme/theme_tokens.dart';

// ════════════════════════════════════════════════════════════════════
//  ATTACHMENT MODEL
// ════════════════════════════════════════════════════════════════════

class Attachment {
  final String label;
  final File? file;
  final String? mimeType;
  final bool isWebSearch;
  final String? searchQuery;

  const Attachment({
    required this.label,
    this.file,
    this.mimeType,
    this.isWebSearch = false,
    this.searchQuery,
  });

  bool get isImage {
    if (mimeType != null) return mimeType!.startsWith('image/');
    if (file == null) return false;
    return (lookupMimeType(file!.path) ?? '').startsWith('image/');
  }

  IconData get icon {
    if (isWebSearch) return Icons.travel_explore_rounded;
    if (isImage) return Icons.image_outlined;
    final m = mimeType ?? lookupMimeType(file?.path ?? '') ?? '';
    if (m.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (m.contains('word') || label.endsWith('.docx')) return Icons.description_outlined;
    if (m.contains('sheet') || label.endsWith('.xlsx') || label.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

// ════════════════════════════════════════════════════════════════════
//  MODULE CONFIG  — ప్రతి screen కి context, prompts, subtitle
// ════════════════════════════════════════════════════════════════════

class AhviModuleConfig {
  final String moduleContext;
  final String subtitle;
  final String hintTextKey;
  final String greetingKey;

  /// Shown when the localization key is missing — keeps each module's
  /// greeting distinct even before translation strings are added.
  final String greetingFallback;

  final List<String> Function(BuildContext) quickPrompts;

  const AhviModuleConfig({
    required this.moduleContext,
    required this.subtitle,
    required this.hintTextKey,
    required this.greetingKey,
    required this.greetingFallback,
    required this.quickPrompts,
  });
}

/// అన్ని screens కి configs — moduleContext తో match అవుతాయి
final Map<String, AhviModuleConfig> _moduleConfigs = {
  'style': AhviModuleConfig(
    moduleContext: 'style',
    subtitle: 'AI Stylist',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'style_chat_greeting',
    greetingFallback: "Hi! I'm your AI Stylist. Tell me about today's occasion or mood and I'll put together the perfect look for you!",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'wear_chip_today'),
      AppLocalizations.t(ctx, 'wear_chip_style_tips'),
    ],
  ),
  'skincare': AhviModuleConfig(
    moduleContext: 'skincare',
    subtitle: 'Skincare Assistant',
    hintTextKey: 'skincare_chat_hint',
    greetingKey: 'skincare_chat_greeting_ahvi',   // renamed — localization లో ఈ key లేకపోతే fallback use అవుతుంది
    greetingFallback: "Hi! I'm your Skincare Assistant. Share your skin type or concerns and I'll recommend the best routine for you!",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'skincare_chip_morning_routine'),
      AppLocalizations.t(ctx, 'skincare_chip_spf'),
    ],
  ),
  'medi': AhviModuleConfig(
    moduleContext: 'medi',
    subtitle: 'Medicine Assistant',
    hintTextKey: 'medi_chat_hint',
    greetingKey: 'medi_chat_greeting',
    greetingFallback: "Hello! I'm your Medicine Assistant. I can help you track medications, check dosage timings, or answer general medicine questions.",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'medi_chip_today'),
      AppLocalizations.t(ctx, 'medi_chip_missed_dose'),
    ],
  ),
  'bills': AhviModuleConfig(
    moduleContext: 'bills',
    subtitle: 'Bills Assistant',
    hintTextKey: 'bills_chat_hint',
    greetingKey: 'bills_chat_greeting',
    greetingFallback: "Hi! I'm your Bills Assistant. Ask me about pending payments, due dates, or your monthly spend summary.",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'bills_chip_pending'),
      AppLocalizations.t(ctx, 'bills_chip_monthly_total'),
    ],
  ),
  'diet': AhviModuleConfig(
    moduleContext: 'diet',
    subtitle: 'Diet & Nutrition Assistant',
    hintTextKey: 'diet_chat_hint',
    greetingKey: 'diet_chat_greeting_ahvi',   // renamed — localization లో ఈ key లేకపోతే fallback use అవుతుంది
    greetingFallback: "Hello! I'm your Diet and Nutrition Assistant. Let's build a meal plan or find high-protein recipes that match your goals!",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'diet_chip_meal_plan'),
      AppLocalizations.t(ctx, 'diet_chip_high_protein'),
    ],
  ),
  'fitness': AhviModuleConfig(
    moduleContext: 'fitness',
    subtitle: 'Fitness Coach',
    hintTextKey: 'fitness_chat_hint',
    greetingKey: 'fitness_chat_greeting',
    greetingFallback: "Hey! I'm your Fitness Coach. Tell me your fitness goal and I'll design a workout plan just for you!",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'fitness_chip_today_workout'),
      AppLocalizations.t(ctx, 'fitness_chip_beginner_plan'),
    ],
  ),
  'wardrobe': AhviModuleConfig(
    moduleContext: 'wardrobe',
    subtitle: 'Wardrobe Stylist',
    hintTextKey: 'wardrobe_chat_hint',
    greetingKey: 'wardrobe_chat_greeting',
    greetingFallback: "Hi! I'm your Wardrobe Stylist. I can help you mix and match outfits or suggest what to add to your wardrobe next!",
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'wardrobe_chip_outfit_today'),
      AppLocalizations.t(ctx, 'wardrobe_chip_buy_next'),
    ],
  ),
};

AhviModuleConfig _configFor(String moduleContext) =>
    _moduleConfigs[moduleContext] ?? _moduleConfigs['style']!;

// ════════════════════════════════════════════════════════════════════
//  PUBLIC API — showAhviStylistChatSheet (same as before, + moduleContext)
// ════════════════════════════════════════════════════════════════════

/// ఏ screen నుండైనా ఇలా call చేయండి:
///   showAhviStylistChatSheet(context, moduleContext: 'bills')
///   showAhviStylistChatSheet(context, moduleContext: 'skincare')
///   showAhviStylistChatSheet(context)  // default: 'style'
Future<void> showAhviStylistChatSheet(
  BuildContext context, {
  String moduleContext = 'style',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final screenH = MediaQuery.of(ctx).size.height;
      final topPad = MediaQuery.of(ctx).padding.top;
      final kbH = MediaQuery.of(ctx).viewInsets.bottom;
      final sheetH = (screenH - topPad) * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: kbH),
        child: SizedBox(
          height: sheetH,
          child: _AhviStylistChatSheet(moduleContext: moduleContext, rootContext: context),
        ),
      );
    },
  );
}

// ════════════════════════════════════════════════════════════════════
//  FAB WIDGET  — same as before, unchanged
// ════════════════════════════════════════════════════════════════════

class AhviStylistFab extends StatefulWidget {
  final VoidCallback onTap;

  const AhviStylistFab({super.key, required this.onTap});

  @override
  State<AhviStylistFab> createState() => _AhviStylistFabState();
}

class _AhviStylistFabState extends State<AhviStylistFab> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.accent.secondary, t.accent.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: t.accent.primary.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: t.accent.secondary.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                child: const Text('✦', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(context, 'ask_ahvi'),
                    style: GoogleFonts.anton(
                      fontSize: 13,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CHAT HISTORY MODEL
// ════════════════════════════════════════════════════════════════════

class _SheetChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<_SheetMessage> messages;

  _SheetChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

// ════════════════════════════════════════════════════════════════════
//  SHEET WIDGET  — universal, module-aware
// ════════════════════════════════════════════════════════════════════

class _AhviStylistChatSheet extends StatefulWidget {
  final String moduleContext;
  final BuildContext rootContext;

  const _AhviStylistChatSheet({
    this.moduleContext = 'style',
    required this.rootContext,
  });

  @override
  State<_AhviStylistChatSheet> createState() => _AhviStylistChatSheetState();
}

class _AhviStylistChatSheetState extends State<_AhviStylistChatSheet>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_SheetMessage> _messages = [];
  bool _typing = false;
  bool _chipsVisible = true;
  bool _chatHasText = false;
  Attachment? _pendingAttachment;

  final List<_SheetChatSession> _history = [];
  String? _currentSessionId;

  AhviModuleConfig get _config => _configFor(widget.moduleContext);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _chatHasText && mounted) {
        setState(() => _chatHasText = hasText);
      }
    });
    // Keyboard వచ్చినప్పుడు scroll to bottom
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
    Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _messages.isNotEmpty) return;
      setState(() {
        _messages.add(_SheetMessage(
          textKey: _config.greetingKey,
          fallback: _config.greetingFallback,
          isUser: false,
        ));
      });
    });
  }

  void _saveCurrentSession() {
    if (_messages.isEmpty) return;
    final userMessages = _messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;
    final rawText = userMessages.first.text ?? '';
    final title = rawText.length > 40 ? '${rawText.substring(0, 40)}…' : rawText;
    final existingIdx = _history.indexWhere((s) => s.id == _currentSessionId);
    final session = _SheetChatSession(
      id: _currentSessionId!,
      title: title,
      createdAt: DateTime.now(),
      messages: List.from(_messages),
    );
    if (existingIdx != -1) {
      _history[existingIdx] = session;
    } else {
      _history.insert(0, session);
    }
  }

  void _startNewChat() {
    _saveCurrentSession();
    Navigator.of(context).pop();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _chipsVisible = true;
      _chatHasText = false;
      _inputController.clear();
      _messages.add(_SheetMessage(textKey: _config.greetingKey, fallback: _config.greetingFallback, isUser: false));
    });
  }

  void _loadSession(_SheetChatSession session) {
    _saveCurrentSession();
    Navigator.of(context).pop();
    setState(() {
      _currentSessionId = session.id;
      _messages..clear()..addAll(session.messages);
      _chipsVisible = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputFocusNode.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {}); // bottomInset re-read కావాలంటే rebuild కావాలి
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Attachment helpers ────────────────────────────────────────────

  void _setPendingAttachment(Attachment a) {
    if (mounted) setState(() => _pendingAttachment = a);
  }

  void _clearPendingAttachment() {
    if (mounted) setState(() => _pendingAttachment = null);
  }

  Future<void> _openAttachment(Attachment att) async {
    if (att.isWebSearch && att.searchQuery != null) {
      final uri = Uri.parse(att.searchQuery!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (att.file != null) await OpenFilex.open(att.file!.path);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'csv', 'xlsx', 'xls', 'pptx'],
      );
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.first;
      if (pf.path == null) return;
      _setPendingAttachment(Attachment(
        label: pf.name,
        file: File(pf.path!),
        mimeType: lookupMimeType(pf.path!) ?? 'application/octet-stream',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('File pick చేయడం సాధ్యపడలేదు'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xfile == null) return;
      _setPendingAttachment(Attachment(
        label: xfile.name,
        file: File(xfile.path),
        mimeType: lookupMimeType(xfile.path) ?? 'image/jpeg',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Photo select చేయడం సాధ్యపడలేదు'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return;
      _setPendingAttachment(Attachment(
        label: 'Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        file: File(xfile.path),
        mimeType: lookupMimeType(xfile.path) ?? 'image/jpeg',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Camera తెరవడం సాధ్యపడలేదు'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _openWebSearchSheet() {
    // Inherit the exact theme from the current context into the modal —
    // this guarantees dark/light tokens are preserved inside the sheet.
    final parentTheme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: parentTheme,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _WebSearchSheet(
              onSearch: (query) {
                Navigator.pop(ctx);
                _setPendingAttachment(Attachment(
                  label: 'Search: "\$query"',
                  isWebSearch: true,
                  searchQuery: 'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
                ));
              },
              onCancel: () => Navigator.pop(ctx),
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingAttachment == null) return;
    if (_typing) return;
    final attachment = _pendingAttachment;
    _inputController.clear();
    setState(() {
      _chipsVisible = false;
      _typing = true;
      _pendingAttachment = null;
      if (trimmed.isNotEmpty) {
        _messages.add(_SheetMessage(text: trimmed, isUser: true));
      }
      if (attachment != null) {
        _messages.add(_SheetMessage(
          text: attachment.isWebSearch
              ? '🔍 ${attachment.label}'
              : attachment.isImage
                  ? '🖼 ${attachment.label}'
                  : '📎 ${attachment.label}',
          isUser: true,
        ));
      }
    });
    _scrollToBottom();

    final replyText = await _callAhviApi(trimmed);

    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add(_SheetMessage(text: replyText, isUser: false));
    });
    _scrollToBottom();
    _saveCurrentSession();
  }

  /// Anthropic API call — module context system prompt తో.
  Future<String> _callAhviApi(String userMessage) async {
    // TODO: Replace with your actual API key or backend proxy URL.
    const apiKey = 'YOUR_ANTHROPIC_API_KEY';

    // Module context బట్టి system prompt set చేయడం
    final systemPrompt = _buildSystemPrompt(widget.moduleContext);

    // Conversation history build చేయడం (greeting తప్ప)
    final historyMessages = _messages
        .where((m) => !m.isGreeting)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text ?? '',
            })
        .where((m) => (m['content'] as String).isNotEmpty)
        .toList();

    // Current user message add చేయడం
    historyMessages.add({'role': 'user', 'content': userMessage});

    try {
      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-3-5-sonnet-20241022',
              'max_tokens': 1024,
              'system': systemPrompt,
              'messages': historyMessages,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List<dynamic>;
        if (content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String? ??
              'Something went wrong. Please try again.';
        }
      }
      return 'Something went wrong. Please try again.';
    } on SocketException {
      return 'No internet connection. Please check your network.';
    } on TimeoutException {
      return 'Request timed out. Please try again.';
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Module బట్టి system prompt
  String _buildSystemPrompt(String moduleContext) {
    switch (moduleContext) {
      case 'skincare':
        return 'You are a professional skincare assistant. Help users with skincare routines, product recommendations, and skin concerns. Be concise, friendly, and practical.';
      case 'medi':
        return 'You are a helpful medicine assistant. Help users track medications, understand dosage timings, and answer general medicine questions. Always remind users to consult a doctor for medical advice.';
      case 'bills':
        return 'You are a bills and finance assistant. Help users manage pending payments, track due dates, and understand their monthly expenses. Be clear and concise.';
      case 'diet':
        return 'You are a diet and nutrition assistant. Help users build meal plans, suggest healthy recipes, and achieve their nutrition goals. Be encouraging and practical.';
      case 'fitness':
        return 'You are a personal fitness coach. Help users with workout plans, exercise tips, and fitness goals. Be motivating and specific.';
      case 'wardrobe':
        return 'You are a wardrobe stylist. Help users mix and match outfits, manage their wardrobe, and suggest new additions. Be creative and fashion-forward.';
      case 'style':
      default:
        return 'You are an AI stylist. Help users choose outfits for occasions, provide style tips, and suggest looks based on their mood and wardrobe. Be friendly and inspiring.';
    }
  }

  // ── History Panel (custom in-sheet slide-in, replaces Flutter Drawer) ──
  bool _drawerOpen = false;

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  Widget _historyPanel() {
    final t = context.themeTokens;
    return AnimatedSlide(
      offset: _drawerOpen ? Offset.zero : const Offset(-1, 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _drawerOpen ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.80,
          decoration: BoxDecoration(
            color: t.backgroundPrimary,
            border: Border(right: BorderSide(color: t.cardBorder, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header — aligned with chat header ────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(children: [
                  Text(
                    AppLocalizations.t(context, 'common_chats'),
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: t.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startNewChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.accent.primary, t.accent.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.t(context, 'common_new'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _closeDrawer,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Icon(Icons.close_rounded, color: t.mutedText, size: 16),
                    ),
                  ),
                ]),
              ),
              Divider(color: t.cardBorder, height: 1),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.t(context, 'chat_no_history'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.mutedText, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _history.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: t.cardBorder, height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (ctx, i) {
                          final session = _history[i];
                          final isActive = session.id == _currentSessionId;
                          return GestureDetector(
                            onTap: () {
                              _closeDrawer();
                              _loadSession(session);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: isActive
                                  ? t.accent.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              child: Row(children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? t.accent.primary.withValues(alpha: 0.15)
                                        : t.panel,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isActive
                                          ? t.accent.primary.withValues(alpha: 0.4)
                                          : t.cardBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '✦',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isActive ? t.accent.primary : t.mutedText,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          color: isActive ? t.accent.primary : t.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${session.messages.length} messages',
                                        style: TextStyle(fontSize: 10, color: t.mutedText),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.accent.primary,
                                    ),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final quickPrompts = _config.quickPrompts(context);

    // Prompt bar estimated height for ListView bottom padding
    const double promptBarH = 72.0;
    final double chipsH = _chipsVisible ? 38.0 : 0.0;
    final double attachH = _pendingAttachment != null ? 52.0 : 0.0;
    final double inputAreaH = promptBarH + chipsH + attachH + 8.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: t.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: t.cardBorder),
        ),
        child: Stack(
          children: [
            // ── Handle + Header + Messages (scrollable) ────────────
            Column(
              children: [
                // ── Handle ─────────────────────────────────────────
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.panelBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: t.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: t.textPrimary,
                            size: 15,
                          ),
                        ),
                      ),
                      AhviHomeText(
                        color: t.textPrimary,
                        fontSize: 30.0,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w400,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openDrawer,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: t.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder, width: 1),
                          ),
                          child: Icon(Icons.history_rounded, color: t.mutedText, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Messages — bottom pad clears the pinned input bar ─
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, inputAreaH + 12),
                    children: [
                      ..._messages.map((msg) => _Bubble(msg: msg)),
                      if (_typing) _TypingBubble(color: t.accent.secondary),
                    ],
                  ),
                ),
              ],
            ),

            // ── Prompt bar — pinned to sheet bottom (sheet itself rises with keyboard) ────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Quick Prompts ───────────────────────────────
                  if (_chipsVisible) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                        height: 28,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: quickPrompts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _sendMessage(quickPrompts[i]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: t.panel,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Text(
                                quickPrompts[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: t.accent.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    // ── Pending Attachment Chip ─────────────────────
                    if (_pendingAttachment != null)
                      _PendingAttachmentChip(
                        attachment: _pendingAttachment!,
                        onRemove: _clearPendingAttachment,
                        onTap: () => _openAttachment(_pendingAttachment!),
                        accent: context.themeTokens.accent.primary,
                        panel: context.themeTokens.panel,
                        cardBorder: context.themeTokens.cardBorder,
                        textPrimary: context.themeTokens.textPrimary,
                        mutedText: context.themeTokens.mutedText,
                      ),
                    // ── Input Bar ───────────────────────────────────
                    AhviChatPromptBar(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      hintText: AppLocalizations.t(context, _config.hintTextKey),
                      hasText: _chatHasText,
                      surface: t.phoneShellInner,
                      border: t.cardBorder,
                      accent: t.accent.primary,
                      accentSecondary: t.accent.secondary,
                      textHeading: t.textPrimary,
                      textMuted: t.mutedText,
                      shadowMedium: t.backgroundPrimary.withValues(alpha: 0.20),
                      onAccent: Colors.white,
                      themeTokens: t,
                      onSendMessage: (message) => _sendMessage(message),
                      onVisualSearch: null,
                      onFindSimilar: null,
                      onAddToWardrobe: null,
                    ),
                  ],
              ),
            ),

            // ── Scrim — dismiss panel on outside tap ─────────────
            if (_drawerOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDrawer,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    color: Colors.black.withValues(alpha: _drawerOpen ? 0.32 : 0.0),
                  ),
                ),
              ),

            // ── History panel — slides in from left ───────────────
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: _historyPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BUBBLE WIDGETS  — same as before
// ════════════════════════════════════════════════════════════════════

class _SheetMessage {
  final String? text;
  final String? textKey;

  /// Used when [textKey] is provided but the localization lookup returns
  /// an empty / missing string — ensures the greeting is always shown.
  final String? fallback;

  final bool isUser;

  _SheetMessage({this.text, this.textKey, this.fallback, required this.isUser})
      : assert(text != null || textKey != null);

  /// Greeting messages (textKey based) API history లో include చేయకూడదు
  bool get isGreeting => textKey != null;

  String resolve(BuildContext context) {
    if (textKey != null) {
      final localized = AppLocalizations.t(context, textKey!);
      // If the key is missing the library typically returns the key itself
      // or an empty string — fall back to the hardcoded greeting in that case.
      if (localized.isNotEmpty && localized != textKey) return localized;
      if (fallback != null) return fallback!;
      return localized;
    }
    return text ?? '';
  }
}

class _Bubble extends StatelessWidget {
  final _SheetMessage msg;

  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: Border.all(color: t.cardBorder),
        ),
        child: msg.isUser
            ? Text(
                msg.resolve(context),
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 8),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: t.accent.primary,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      msg.resolve(context),
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ADD MENU ROW  — list style matching design
// ════════════════════════════════════════════════════════════════════

class _AddMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final Color accentSecondary;
  final Color panel;
  final Color cardBorder;
  final Color textPrimary;
  final Color mutedText;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _AddMenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.accentSecondary,
    required this.panel,
    required this.cardBorder,
    required this.textPrimary,
    required this.mutedText,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_AddMenuRow> createState() => _AddMenuRowState();
}

class _AddMenuRowState extends State<_AddMenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: widget.isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.accent.withValues(alpha: 0.18),
                          widget.accentSecondary.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.mutedText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: widget.cardBorder,
                indent: 74,
                endIndent: 0,
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PENDING ATTACHMENT CHIP  — shows selected file/photo above input
// ════════════════════════════════════════════════════════════════════

class _PendingAttachmentChip extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final Color accent;
  final Color panel;
  final Color cardBorder;
  final Color textPrimary;
  final Color mutedText;

  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
    required this.onTap,
    required this.accent,
    required this.panel,
    required this.cardBorder,
    required this.textPrimary,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            if (attachment.isImage && attachment.file != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Image.file(
                  attachment.file!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Icon(attachment.icon, color: accent, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attachment.isWebSearch
                        ? 'Tap to preview in browser'
                        : attachment.isImage
                            ? 'Image — tap to view'
                            : 'Tap to open',
                    style: TextStyle(fontSize: 10, color: mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: mutedText),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  WEB SEARCH SHEET  — themed to match Ahvi design
// ════════════════════════════════════════════════════════════════════

class _WebSearchSheet extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onCancel;

  const _WebSearchSheet({
    required this.onSearch,
    required this.onCancel,
  });

  @override
  State<_WebSearchSheet> createState() => _WebSearchSheetState();
}

class _WebSearchSheetState extends State<_WebSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();

  static const _suggestions = [
    'Outfit ideas today',
    'Skincare routine',
    'Diet plan this week',
    'Fitness tips',
    'Trending styles',
    'Hyderabad weather',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── All colors from themeTokens — auto dark/light ──────────────
    final t = context.themeTokens;
    final accent      = t.accent.primary;
    final accentSec   = t.accent.secondary;
    final panel       = t.panel;
    final cardBorder  = t.cardBorder;
    final textPrimary = t.textPrimary;
    final mutedText   = t.mutedText;
    final bgColor     = t.backgroundPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.travel_explore_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Web Search',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),

          ]),
          const SizedBox(height: 14),
          // ── Search field ──────────────────────────────────────────
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ఏమి search చేయాలి?',
              hintStyle: TextStyle(color: mutedText, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: accent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              filled: true,
              fillColor: panel,
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: mutedText),
                      onPressed: () => setState(() => _ctrl.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: widget.onSearch,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 11,
              color: mutedText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => widget.onSearch(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ctrl.text.trim().isNotEmpty
                  ? () => widget.onSearch(_ctrl.text.trim())
                  : null,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search చేయండి'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accentSec.withValues(alpha: 0.10),
                disabledForegroundColor: mutedText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final Color color;

  const _TypingBubble({required this.color});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.themeTokens.panel,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: context.themeTokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final p = ((_controller.value + i * 0.2) % 1.0);
                final o = 0.35 + (0.65 * (1 - (p - 0.5).abs() * 2));
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: o),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
// ════════════════════════════════════════════════════════════════════
//  AhviPlusMenuButton  — Self-contained ChatGPT-style popup widget
//  Usage: AhviChatPromptBar(plusButton: AhviPlusMenuButton(...))
// ════════════════════════════════════════════════════════════════════

class AhviPlusMenuButton extends StatefulWidget {
  final Color accent;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onCapture;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final VoidCallback onSearch;
  final void Function(bool isOpen)? onMenuToggle;

  const AhviPlusMenuButton({
    super.key,
    required this.accent,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onCapture,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onSearch,
    this.onMenuToggle,
  });

  @override
  State<AhviPlusMenuButton> createState() => _AhviPlusMenuButtonState();
}

class _AhviPlusMenuButtonState extends State<AhviPlusMenuButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() => _isOpen = true);
    widget.onMenuToggle?.call(true);

    final items = [
      _MenuItem(Icons.camera_alt_rounded,        'Camera',        const Color(0xFFFF6B6B), widget.onCapture),
      _MenuItem(Icons.photo_library_rounded,     'Photo Library', const Color(0xFF4ECDC4), widget.onPickPhoto),
      _MenuItem(Icons.insert_drive_file_rounded, 'Files',         const Color(0xFF45B7D1), widget.onPickFile),
      _MenuItem(Icons.travel_explore_rounded,    'Search',        const Color(0xFF96CEB4), widget.onSearch),
    ];

    _overlay = OverlayEntry(
      builder: (ctx) => _PlusPopupOverlay(
        link: _link,
        items: items,
        bgColor: widget.bgColor,
        borderColor: widget.borderColor,
        textColor: widget.textColor,
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() => _isOpen = false);
      widget.onMenuToggle?.call(false);
    }
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _isOpen
                ? widget.accent.withValues(alpha: 0.20)
                : widget.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _isOpen
                  ? widget.accent.withValues(alpha: 0.45)
                  : widget.accent.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(Icons.add_rounded, color: widget.accent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Internal popup overlay ────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}

class _PlusPopupOverlay extends StatefulWidget {
  final LayerLink link;
  final List<_MenuItem> items;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _PlusPopupOverlay({
    required this.link,
    required this.items,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_PlusPopupOverlay> createState() => _PlusPopupOverlayState();
}

class _PlusPopupOverlayState extends State<_PlusPopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Outside tap → dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // Popup card — appears above the + button
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.13),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.asMap().entries.map((e) {
                      final isLast = e.key == widget.items.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              widget.onDismiss();
                              e.value.onTap();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: e.value.color,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(e.value.icon,
                                        size: 17, color: Colors.white),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    e.value.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: widget.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 0,
                              thickness: 0.5,
                              color: widget.borderColor,
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ), 
        ),
      ],
    );
  }
}

// Full chat page logic lives here so AhVi stylish chat is the single chat implementation.
Map<String, List<String>> _getChipsByModule(BuildContext context) => {
  'style': [
    AppLocalizations.t(context, 'intent_style_s1'),
    AppLocalizations.t(context, 'intent_style_s2'),
    AppLocalizations.t(context, 'intent_style_s3'),
  ],
  'organize': [
    AppLocalizations.t(context, 'intent_organize_s1'),
    AppLocalizations.t(context, 'intent_organize_s2'),
    AppLocalizations.t(context, 'intent_organize_s3'),
    AppLocalizations.t(context, 'intent_organize_s4'),
    AppLocalizations.t(context, 'intent_organize_s5'),
    AppLocalizations.t(context, 'intent_organize_s6'),
    AppLocalizations.t(context, 'intent_organize_s7'),
    AppLocalizations.t(context, 'intent_organize_s8'),
  ],
  'plan': [
    AppLocalizations.t(context, 'intent_prepare_s1'),
    AppLocalizations.t(context, 'intent_prepare_s2'),
    AppLocalizations.t(context, 'intent_prepare_s3'),
  ],
};

class _PageChatMessage {
  final String text;
  final bool isMe;
  final bool isGreeting;
  final List<dynamic> chips;
  final String? boardId;
  final String? packId;
  final _LocalResponse? local;
  _PageChatMessage({
    required this.text,
    required this.isMe,
    this.isGreeting = false,
    this.chips = const [],
    this.boardId,
    this.packId,
    this.local,
  });
}

enum _RespType { outfits, plan, card, checklist }

class _LocalResponse {
  final _RespType type;
  final String intro;
  final List<_Outfit> outfits;
  final List<_Plan> plans;
  final _CardData? card;
  const _LocalResponse({
    required this.type,
    required this.intro,
    this.outfits = const [],
    this.plans = const [],
    this.card,
  });
}

class _Outfit {
  final String name;
  final List<String> tags;
  final String image;
  final String description;
  bool saved;
  _Outfit(this.name, this.tags, this.image,
      {this.description = '', this.saved = false});
}

class _Plan {
  final String title;
  final List<String> items;
  const _Plan(this.title, this.items);
}

class _CardData {
  final String title;
  final IconData icon;
  final List<_CardRow> rows;
  final String footer;
  final String pageKey;
  const _CardData(this.title, this.icon, this.rows, this.footer, this.pageKey);
}

class _CardRow {
  final bool done;
  final String main;
  final String sub;
  final String tag;
  const _CardRow(this.done, this.main, this.sub, this.tag);
}

final _local = <String, _LocalResponse>{
  'What should I wear today?': _LocalResponse(
    type: _RespType.outfits,
    intro:
        "Based on today's 14°C partly cloudy weather, here are 3 looks curated for you:",
    outfits: [
      _Outfit(
        'Layered Minimal',
        ['Casual', 'Today'],
        'https://images.unsplash.com/photo-1594938298603-c8148c4b9c2b?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'A light knit layered over a crisp tee with slim trousers. Comfortable yet polished for a cool day.',
      ),
      _Outfit(
        'Smart Casual',
        ['Office', 'Versatile'],
        'https://images.unsplash.com/photo-1591369822096-ffd140ec948f?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'Tailored chinos paired with a structured shirt. Effortless transition from desk to dinner.',
      ),
      _Outfit(
        'Street Edit',
        ['Urban', 'Fresh'],
        'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'Wide-leg joggers with an oversized graphic tee and clean sneakers. Relaxed city energy.',
      ),
    ],
  ),
  'Build a rooftop party outfit': _LocalResponse(
    type: _RespType.outfits,
    intro:
        "Rooftop energy calls for elevated looks. Here's what works perfectly:",
    outfits: [
      _Outfit(
        'Evening Glow',
        ['Party', 'Night'],
        'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'A sleek satin slip dress with strappy heels. Warm-toned accessories complete the golden-hour vibe.',
      ),
      _Outfit(
        'Rooftop Chic',
        ['Elevated', 'Cool'],
        'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'Tailored wide-leg trousers with a cropped blazer. Sharp, confident and built for the skyline.',
      ),
      _Outfit(
        'Bold Statement',
        ['Trendy', 'Standout'],
        'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'A vibrant co-ord set that commands attention. Minimal jewellery lets the colour do the talking.',
      ),
    ],
  ),
  'Show trending casual looks': _LocalResponse(
    type: _RespType.outfits,
    intro:
        'Quiet luxury and clean lines are having a moment. Top trending now:',
    outfits: [
      _Outfit(
        'Quiet Luxury',
        ['Trending', 'Minimal'],
        'https://images.unsplash.com/photo-1538805060514-97d9cc17730c?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'Cream wide-leg trousers with a fine-knit cardigan. Understated elegance that speaks volumes.',
      ),
      _Outfit(
        'Soft Tones',
        ['Casual', 'Neutral'],
        'https://images.unsplash.com/photo-1594938298603-c8148c4b9c2b?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'Dusty beige linen set with white sneakers. Easy, breathable and endlessly wearable.',
      ),
      _Outfit(
        'Classic Ease',
        ['Everyday', 'Fresh'],
        'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=220&h=260&fit=crop&crop=top&auto=format',
        description: 'A white oversized button-down tucked into straight jeans. The perfect no-fuss uniform.',
      ),
    ],
  ),
  'Plan a 3-day Goa trip': _LocalResponse(
    type: _RespType.checklist,
    intro: "Here's your expert-curated 3-day Goa itinerary:",
    plans: [
      _Plan('Day 1 — Arrival & North Goa', [
        '☀️ Arrive & check in',
        '🏖️ Baga Beach',
        '🍽️ Dinner at Thalassa',
      ]),
      _Plan('Day 2 — Culture & South Goa', [
        '🏛️ Old Goa churches',
        '🚗 Drive to Palolem',
        '🌅 Sunset at Cabo de Rama',
      ]),
      _Plan('Day 3 — Relax & Depart', [
        '🧘 Morning yoga',
        '🛍️ Anjuna flea market',
        '✈️ Airport by 4pm',
      ]),
    ],
  ),
  'Pack for business travel': _LocalResponse(
    type: _RespType.checklist,
    intro: 'Smart packing list — nothing missing, nothing extra:',
    plans: [
      _Plan('👔 Clothing', ['2× formal shirts', '1× blazer', '2× trousers']),
      _Plan('💼 Work Essentials', [
        'Laptop + charger',
        'Notebook + pens',
        'Portable battery',
      ]),
      _Plan('🧴 Toiletries', [
        'Moisturiser, deodorant',
        'Toothbrush + paste',
        'Face wash + razor',
      ]),
    ],
  ),
  'Create a wedding checklist': _LocalResponse(
    type: _RespType.checklist,
    intro: 'Complete wedding checklist — 24 items across 4 categories:',
    plans: [
      _Plan('📆 6–12 Months Before', [
        'Set budget & guest list',
        'Book venue & caterer',
        'Book photographer',
      ]),
      _Plan('🎨 3–6 Months Before', [
        'Send invitations',
        'Finalise menu',
        'Book hair & makeup',
      ]),
      _Plan('✅ Week Of', [
        'Final dress fitting',
        'Prepare wedding day kit',
        'Rest & enjoy 🎉',
      ]),
    ],
  ),
  'Today\'s meals': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 4 meals planned today.',
    card: _CardData(
      'Meals',
      Icons.restaurant_menu_rounded,
      [
        _CardRow(
          true,
          'Oats with banana & honey',
          'Breakfast · 380 kcal',
          'Breakfast',
        ),
        _CardRow(true, 'Dal rice with salad', 'Lunch · 620 kcal', 'Lunch'),
        _CardRow(
          false,
          'Grilled paneer with roti',
          'Dinner · 540 kcal',
          'Dinner',
        ),
      ],
      'Open Meals',
      'meal',
    ),
  ),
  'My medicines': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 3 medicines tracked.',
    card: _CardData(
      'Medicines',
      Icons.medication_rounded,
      [
        _CardRow(true, 'Vitamin D3 — 1 tablet', 'Daily · 08:00', 'Taken'),
        _CardRow(true, 'Iron Supplement — 1 tablet', 'Daily · 13:00', 'Taken'),
        _CardRow(false, 'Omega-3 — 2 capsules', 'Daily · 20:00', 'Pending'),
      ],
      'Open Medicines',
      'medi',
    ),
  ),
  'Pending bills': _LocalResponse(
    type: _RespType.card,
    intro: 'You have 3 unpaid bills.',
    card: _CardData(
      'Bills',
      Icons.receipt_long_rounded,
      [
        _CardRow(false, 'Rent', 'Due: Mar 28 · Rent', '₹12,000'),
        _CardRow(
          false,
          'Netflix + Hotstar',
          'Due: Apr 03 · Subscription',
          '₹649',
        ),
        _CardRow(false, 'Phone Recharge', 'Due: Apr 05 · Utilities', '₹299'),
      ],
      'Open Bills',
      'bill',
    ),
  ),
  'Today\'s workout': _LocalResponse(
    type: _RespType.card,
    intro: 'Today\'s workout has 5 exercises.',
    card: _CardData(
      'Workout',
      Icons.fitness_center_rounded,
      [
        _CardRow(true, 'Warm-up cardio', 'Cardio · 1 set · 10 min', 'Cardio'),
        _CardRow(false, 'Squats', 'Strength · 4 sets · 12 reps', 'Strength'),
        _CardRow(false, 'Lunges', 'Strength · 3 sets · 15 reps', 'Strength'),
      ],
      'Open Workout',
      'workout',
    ),
  ),
  'Upcoming events': _LocalResponse(
    type: _RespType.card,
    intro: 'Here are your upcoming events.',
    card: _CardData(
      'Events',
      Icons.event_note_rounded,
      [
        _CardRow(
          false,
          'Doctor Appointment',
          '24 Mar · 11:00 AM · Apollo Clinic',
          'Health',
        ),
        _CardRow(false, 'Dinner with family', '24 Mar · 07:30 PM', 'Personal'),
        _CardRow(
          false,
          'Spanish Class',
          '28 Mar · 06:00 PM · Online',
          'Learning',
        ),
      ],
      'Open Calendar',
      'calendar',
    ),
  ),
  'Today\'s events': _LocalResponse(
    type: _RespType.card,
    intro: 'No events scheduled for today.',
    card: _CardData(
      'Events',
      Icons.today_rounded,
      [
        _CardRow(
          false,
          'Doctor Appointment',
          '24 Mar · 11:00 AM · Apollo Clinic',
          'Health',
        ),
        _CardRow(false, 'Dinner with family', '24 Mar · 07:30 PM', 'Personal'),
      ],
      'Open Calendar',
      'calendar',
    ),
  ),
  'Morning skincare': _LocalResponse(
    type: _RespType.card,
    intro: 'Your morning routine has 4 steps.',
    card: _CardData(
      'Skincare',
      Icons.spa_rounded,
      [
        _CardRow(
          true,
          'Gentle Cleanser',
          'CeraVe · Morning · Step 1',
          'Step 1',
        ),
        _CardRow(
          true,
          'Vitamin C Serum',
          'Minimalist · Morning · Step 2',
          'Step 2',
        ),
        _CardRow(
          true,
          'SPF 50 Sunscreen',
          'Biore · Morning · Step 4',
          'Step 4',
        ),
      ],
      'Open Skincare',
      'skincare',
    ),
  ),
};

// ── Persistent chat session model ──────────────────────────────────────────

class _PageChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  final List<Map<String, String>> history; // [{role, content}]

  _PageChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.history,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'history': history,
      };

  factory _PageChatSession.fromJson(Map<String, dynamic> j) => _PageChatSession(
        id: j['id'] as String,
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        history: (j['history'] as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
      );
}

const _kSessionsKey = 'ahvi_chat_sessions';

class ChatScreen extends StatefulWidget {
  final String moduleContext;
  final String? initialPrompt;
  final bool showBackButton;
  const ChatScreen({
    super.key,
    this.moduleContext = 'style',
    this.initialPrompt,
    this.showBackButton = true,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_PageChatMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  String _runningMemory = '';
  bool _isTyping = false;
  String _userName = 'User';
  final Map<String, List<List<bool>>> _checklistChecksByTitle = {};
  final Map<String, List<List<String>>> _checklistItemsByTitle = {};
  final Map<String, List<TextEditingController>> _checklistAddCtrlsByTitle = {};
  final Map<String, bool> _checklistSavedByTitle = {};

  // ── Voice ──────────────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // ── History ────────────────────────────────────────────────────────────────
  List<_PageChatSession> _sessions = [];
  late String _currentSessionId;
  bool _greetingAdded = false;
  String get _module => widget.moduleContext.toLowerCase().trim() == 'prepare'
      ? 'plan'
      : widget.moduleContext.toLowerCase().trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadSessions();
    _initSpeech();

    // Keyboard వచ్చినప్పుడు scroll to bottom
    _chatFocusNode.addListener(() {
      if (_chatFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greetingAdded) {
      _greetingAdded = true;
      _fetchUser();
      _messages.add(
        _PageChatMessage(
          text: '',
          isMe: false,
          isGreeting: true,
        ),
      );
      final pendingPrompt = widget.initialPrompt?.trim();
      if (pendingPrompt != null && pendingPrompt.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sendMessage(pendingPrompt);
        });
      }
    }
  }

  Future<void> _fetchUser() async {
    final appwrite = Provider.of<AppwriteService>(context, listen: false);
    final user = await appwrite.getCurrentUser();
    if (user != null && mounted) {
      setState(
        () => _userName = user.name.isNotEmpty
            ? user.name.split(' ').first
            : 'Stylist',
      );
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _chatController.text = result.recognizedWords;
            _chatController.selection = TextSelection.fromPosition(
              TextPosition(offset: _chatController.text.length),
            );
          });
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_IN',
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  // ── Session persistence ────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionsKey);
    if (raw == null) return;
    try {
      final List decoded = jsonDecode(raw) as List;
      if (mounted) {
        setState(() {
          _sessions = decoded
              .map((e) => _PageChatSession.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCurrentSession() async {
    if (_chatHistory.isEmpty) return; // nothing to persist yet
    final prefs = await SharedPreferences.getInstance();

    // Build a readable title from the first user message
    final firstUser = _chatHistory.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'content': 'Chat'},
    );
    final title = (firstUser['content'] ?? 'Chat').length > 40
        ? '${firstUser['content']!.substring(0, 40)}…'
        : firstUser['content']!;

    final existing = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (existing >= 0) {
      _sessions[existing].history
        ..clear()
        ..addAll(_chatHistory);
      _sessions[existing].title = title;
    } else {
      _sessions.insert(
        0,
        _PageChatSession(
          id: _currentSessionId,
          title: title,
          createdAt: DateTime.now(),
          history: List.from(_chatHistory),
        ),
      );
    }

    await prefs.setString(
      _kSessionsKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _deleteSession(String id) async {
    setState(() => _sessions.removeWhere((s) => s.id == id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSessionsKey,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  void _startNewChat() {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages
        ..clear()
        ..add(_PageChatMessage(
          text: '',
          isMe: false,
          isGreeting: true,
        ));
      _chatHistory.clear();
      _runningMemory = '';
    });
    _scrollToBottom();
  }

  void _loadSession(_PageChatSession session) {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = session.id;
      _chatHistory
        ..clear()
        ..addAll(session.history);
      _messages.clear();
      // Rebuild _messages from history for display
      _messages.add(_PageChatMessage(
        text: '',
        isMe: false,
        isGreeting: true,
      ));
      for (final h in session.history) {
        _messages.add(_PageChatMessage(
          text: h['content'] ?? '',
          isMe: h['role'] == 'user',
        ));
      }
      _runningMemory = '';
    });
    _scrollToBottom();
  }

  void _handleChipTap(String chip) {
    final local = _local[chip];
    if (local == null) return _sendMessage(chip);
    setState(() {
      _messages.add(_PageChatMessage(text: chip, isMe: true));
      _messages.add(_PageChatMessage(text: local.intro, isMe: false, local: local));
    });
    _scrollToBottom();
  }

  void _sendMessage([String? chipText]) async {
    final text = chipText ?? _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _messages.add(_PageChatMessage(text: text, isMe: true));
      _chatHistory.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _scrollToBottom();
    try {
      final backend = Provider.of<BackendService>(context, listen: false);
      final response = await backend.sendChatQuery(
        text,
        'user_$_userName',
        List<Map<String, String>>.from(_chatHistory),
        _runningMemory,
      );
      if (!mounted) return;
      if (response['updated_memory'] != null) {
        _runningMemory = response['updated_memory'];
      }
      final aiText =
          response['message']?['content']?.toString() ??
          AppLocalizations.t(context, 'chat_connection_error');
      _chatHistory.add({'role': 'assistant', 'content': aiText});
      setState(
        () => _messages.add(
          _PageChatMessage(
            text: aiText,
            isMe: false,
            chips: response['chips'] ?? [],
            boardId: response['board_ids'],
            packId: response['pack_ids'],
          ),
        ),
      );
      _saveCurrentSession();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _PageChatMessage(text: '${AppLocalizations.t(context, 'chat_error_prefix')}: $e', isMe: false),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  void _openOrganizePage(String pageKey) {
    Widget? page;
    switch (pageKey) {
      case 'meal':
        page = diet_page.MainScreen(showBackButton: true); // ✅ Organise నుండి వస్తుంది
        break;
      case 'medi':
        page = medi_tracker_page.MediTrackScreen(showBackButton: true); // ✅
        break;
      case 'bill':
        page = bills_page.BillsScreen(showBackButton: true); // ✅
        break;
      case 'workout':
        page = fitness_page.WorkoutStudioScreen(showBackButton: true); // ✅
        break;
      case 'calendar':
        page = const calendar_page.CalendarShell(); // calendar లో వేరే implement చేయాలి
        break;
      case 'skincare':
        page = const skincare_page.SkincareScreen(); // skincare లో వేరే implement చేయాలి
        break;
    }
    if (page == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SafeArea(top: true, bottom: false, child: page!),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();
    for (final ctrls in _checklistAddCtrlsByTitle.values) {
      for (final c in ctrls) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // setState() లేదు — keyboard వచ్చినప్పుడు full rebuild అవ్వదు.
    // Prompt bar & message list వున్న Builder widgets MediaQuery ని
    // directly read చేస్తాయి కాబట్టి Flutter automatically re-layouts చేస్తుంది.
    // setState() వేస్తే logo కూడా rebuild అయి jump అవుతుంది.
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: t.backgroundPrimary,
      drawer: _historyDrawer(t),
      // resizeToAvoidBottomInset: true — keyboard వచ్చినప్పుడు Scaffold body
      // automatically shrink అవుతుంది. Logo header Column లో first child కాబట్టి
      // keyboard తో పైకి వెళ్ళదు — SafeArea లో ఉంది, Scaffold body shrink
      // అయినా SafeArea top padding change కాదు.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Logo header — AhviHeader (StatelessWidget, never rebuilds) ──
            AhviHeader(
              showBack: widget.showBackButton,
              showBorder: false,
              frosted: true,
              right: IconButton(
                icon: Icon(Icons.history_rounded, color: context.themeTokens.textPrimary),
                tooltip: AppLocalizations.t(context, 'chat_history_btn'),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),

            // ── Message list + typing indicator ──
            Expanded(
              child: Builder(
                builder: (context) {
                  final double kbH = MediaQuery.of(context).viewInsets.bottom;
                  final double navBarH = MediaQuery.viewPaddingOf(context).bottom;
                  const double promptBarH = 80.0;
                  final double listBottomPad = kbH > 0
                      ? promptBarH
                      : navBarH + promptBarH + (widget.showBackButton ? 0 : 80);
                  return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(20, 16, 20, listBottomPad),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_isTyping && i == _messages.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: _PageTypingBubble(),
                            ),
                          );
                        }
                        return _msg(_messages[i], t);
                      },
                  );
                },
              ),
            ),

            // ── Prompt bar — keyboard వచ్చినప్పుడు Scaffold shrink వల్ల
            // automatically keyboard పైకి వస్తుంది. Extra padding వద్దు. ──
            Builder(
              builder: (context) {
                final double navBarH = MediaQuery.viewPaddingOf(context).bottom;
                final double kbH = MediaQuery.of(context).viewInsets.bottom;
                // Keyboard open అయినప్పుడు Scaffold already shrunk — navBar pad వద్దు
                final double bottomPad = kbH > 0
                    ? 0
                    : navBarH + (widget.showBackButton ? 0 : 80);
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: _input(t),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyDrawer(AppThemeTokens t) {
    return Drawer(
      backgroundColor: t.backgroundSecondary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.t(context, 'chat_history_title'),
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startNewChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.accent.primary, t.accent.secondary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.t(context, 'chat_new'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: t.cardBorder, height: 1),
            // Session list
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.t(context, 'chat_no_history'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.mutedText, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (ctx, i) {
                        final s = _sessions[i];
                        final isActive = s.id == _currentSessionId;
                        final date = _formatDate(s.createdAt);
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.withValues(alpha: 0.15),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                          ),
                          onDismissed: (_) => _deleteSession(s.id),
                          child: ListTile(
                            selected: isActive,
                            selectedTileColor:
                                t.accent.primary.withValues(alpha: 0.1),
                            onTap: () => _loadSession(s),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 2),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? t.accent.primary.withValues(alpha: 0.2)
                                    : t.panel,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 16,
                                color: isActive ? t.accent.primary : t.mutedText,
                              ),
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              date,
                              style:
                                  TextStyle(color: t.mutedText, fontSize: 11),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return AppLocalizations.t(context, 'chat_today');
    if (diff.inDays == 1) return AppLocalizations.t(context, 'chat_yesterday');
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _msg(_PageChatMessage m, AppThemeTokens t) => Column(
    crossAxisAlignment: m.isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Align(
        alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.panel,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.isMe ? 18 : 4),
              bottomRight: Radius.circular(m.isMe ? 4 : 18),
            ),
            border: Border.all(color: t.cardBorder),
          ),
          child: m.isMe
              ? Text(
                  m.text,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1, right: 8),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: t.accent.primary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        m.isGreeting
                            ? AppLocalizations.t(context, 'chat_greeting')
                            : m.text,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      if (!m.isMe && m.local != null) _localView(m.local!, t),
      if (!m.isMe && m.chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: m.chips
                .map(
                  (c) => GestureDetector(
                    onTap: () => _sendMessage(c.toString()),
                    child: _chip(c.toString(), t),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );

  Widget _localView(_LocalResponse r, AppThemeTokens t) {
    if (r.type == _RespType.outfits) {
      final screenW = MediaQuery.of(context).size.width;
      final screenH = MediaQuery.of(context).size.height;
      final outfitCardW = (screenW * 0.30).clamp(100.0, 140.0);
      final outfitStripH = (screenH * 0.22).clamp(155.0, 195.0);
      final outfitImgH = outfitStripH * 0.62;
      return SizedBox(
        height: outfitStripH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: r.outfits.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final o = r.outfits[i];
            final heroTag = 'outfit_hero_${o.name}_$i';
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    opaque: false,
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 420),
                    reverseTransitionDuration: const Duration(milliseconds: 320),
                    pageBuilder: (ctx, animation, _) => FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                      ),
                      child: _OutfitDetailPage(
                        outfit: o,
                        heroTag: heroTag,
                        t: t,
                        onSaveChanged: (saved) =>
                            setState(() => o.saved = saved),
                      ),
                    ),
                  ),
                );
              },
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: outfitCardW,
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: t.backgroundPrimary.withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                o.image,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                cacheWidth: 280,
                                errorBuilder: (_, __, ___) => Container(
                                  color: t.accent.primary.withValues(alpha: 0.1),
                                  child: Icon(Icons.image_outlined,
                                      color: t.mutedText, size: 28),
                                ),
                              ),
                              // Saved badge
                              if (o.saved)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.accent.primary
                                          .withValues(alpha: 0.88),
                                    ),
                                    child: Icon(Icons.bookmark_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        size: 10),
                                  ),
                                ),
                              // Bottom gradient
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        t.backgroundPrimary
                                            .withValues(alpha: 0.40),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Label
                        Padding(
                          padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name,
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 3,
                                children: o.tags.take(2).map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t.accent.primary
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: t.mutedText,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    if (r.type == _RespType.plan) {
      final colors = [t.accent.primary, t.accent.secondary, t.accent.tertiary];
      return Column(
        children: r.plans
            .asMap()
            .entries
            .map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors[e.key % 3], width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.value.title,
                      style: TextStyle(
                        color: colors[e.key % 3],
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...e.value.items.map(
                      (it) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          it,
                          style: TextStyle(
                            color: t.mutedText,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }
    if (r.type == _RespType.checklist) {
      return _buildChecklistCard(r, t);
    }
    final d = r.card!;
    final accent = t.accent.primary;
    final done = d.rows.where((x) => x.done).length;
    return Container(
      margin: EdgeInsets.only(
        left: 4,
        right: (MediaQuery.of(context).size.width * 0.07).clamp(16.0, 28.0),
        bottom: 16,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(d.icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.title,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '$done/${d.rows.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...d.rows.map(
            (x) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: t.panel.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.cardBorder.withValues(alpha: 0.9)),
              ),
              child: Row(
                children: [
                  Icon(
                    x.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: x.done ? accent : t.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x.main,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          x.sub,
                          style: TextStyle(color: t.mutedText, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      x.tag,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openOrganizePage(d.pageKey),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.cardBorder)),
              ),
              child: Text(
                d.footer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(_LocalResponse r, AppThemeTokens t) {
    final title = r.intro.isNotEmpty ? r.intro : 'Checklist';
    const sections = [
      (
        name: 'Documents',
        emoji: '📄',
        color: Color(0xFF04D7C8), // teal - keep as semantic category color
        items: [
          'Passport / ID',
          'Boarding pass',
          'Travel insurance',
          'Hotel confirmation',
          'Visa (if required)',
        ],
      ),
      (
        name: 'Tech & Power',
        emoji: '🔌',
        color: Color(0xFF8D7DFF),
        items: [
          'Phone + charger',
          'Power bank',
          'Headphones',
          'Laptop or tablet',
          'Universal adapter',
        ],
      ),
      (
        name: 'Comfort',
        emoji: '😴',
        color: Color(0xFF6B91FF),
        items: [
          'Neck pillow',
          'Eye mask',
          'Earplugs',
          'Light jacket',
          'Compression socks',
        ],
      ),
    ];
    const sectionImages = [
      [
        'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1522199755839-a2bacb67c546?w=400&h=260&fit=crop&auto=format',
      ],
      [
        'https://images.unsplash.com/photo-1517336714739-489689fd1ca8?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1593344484962-796055d4a3a4?w=400&h=260&fit=crop&auto=format',
      ],
      [
        'https://images.unsplash.com/photo-1520006403909-838d6b92c22e?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1506485338023-6ce5f36692df?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=400&h=260&fit=crop&auto=format',
        'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=400&h=260&fit=crop&auto=format',
      ],
    ];

    final itemsState = _checklistItemsByTitle.putIfAbsent(
      title,
      () => sections.map((s) => List<String>.from(s.items)).toList(),
    );
    final addCtrls = _checklistAddCtrlsByTitle.putIfAbsent(
      title,
      () => List.generate(sections.length, (_) => TextEditingController()),
    );
    final checksState = _checklistChecksByTitle.putIfAbsent(
      title,
      () => itemsState
          .map(
            (items) => List<bool>.filled(items.length, false, growable: true),
          )
          .toList(),
    );
    final isSaved = _checklistSavedByTitle[title] ?? false;

    for (var i = 0; i < itemsState.length; i++) {
      final targetLen = itemsState[i].length;
      if (checksState[i].length < targetLen) {
        checksState[i].addAll(
          List<bool>.filled(
            targetLen - checksState[i].length,
            false,
            growable: true,
          ),
        );
      } else if (checksState[i].length > targetLen) {
        checksState[i] = checksState[i].sublist(0, targetLen);
      }
    }

    return StatefulBuilder(
      builder: (context, checklistSetState) {
        final totalItems = itemsState.fold<int>(
          0,
          (sum, items) => sum + items.length,
        );
        final totalChecked = checksState.fold<int>(
          0,
          (sum, items) => sum + items.where((v) => v).length,
        );
        final progress = totalItems == 0 ? 0.0 : totalChecked / totalItems;

        return Container(
          margin: EdgeInsets.only(
            left: 4,
            right: (MediaQuery.of(context).size.width * 0.07).clamp(16.0, 28.0),
            bottom: 16,
          ),
          decoration: BoxDecoration(
            color: t.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.cardBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: t.phoneShell,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.intro,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalChecked of $totalItems items',
                      style: TextStyle(
                        color: t.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 7,
                      decoration: BoxDecoration(
                        color: t.cardBorder.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 300),
                          widthFactor: progress,
                          alignment: Alignment.centerLeft,
                          child: Container(color: t.accent.tertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(sections.length, (sIdx) {
                final s = sections[sIdx];
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border(
                      top: BorderSide(
                        color: t.cardBorder.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.emoji),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: sectionImages[sIdx].length,
                          itemExtent: 88,
                          itemBuilder: (_, imgIdx) {
                            final img = sectionImages[sIdx][imgIdx];
                            return Padding(
                              padding: EdgeInsets.only(
                                right: imgIdx == sectionImages[sIdx].length - 1
                                    ? 0
                                    : 8,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: t.cardBorder.withValues(alpha: 0.85),
                                  ),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: Image.network(
                                  img,
                                  fit: BoxFit.cover,
                                  cacheWidth: 264,
                                  cacheHeight: 192,
                                  errorBuilder: (_, _, _) => Container(
                                    color: t.panel.withValues(alpha: 0.75),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 16,
                                      color: t.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(itemsState[sIdx].length, (i) {
                        final done = checksState[sIdx][i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: t.panel.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.cardBorder.withValues(alpha: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => checklistSetState(
                                  () => checksState[sIdx][i] = !done,
                                ),
                                child: Icon(
                                  done
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: done ? s.color : t.mutedText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  itemsState[sIdx][i],
                                  style: TextStyle(
                                    color: done ? t.mutedText : t.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  checklistSetState(() {
                                    itemsState[sIdx].removeAt(i);
                                    checksState[sIdx].removeAt(i);
                                  });
                                },
                                child: Text(
                                  '×',
                                  style: TextStyle(
                                    color: t.mutedText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.phoneShellInner.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: addCtrls[sIdx],
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.t(context, 'chat_add_item'),
                                  hintStyle: TextStyle(
                                    color: t.mutedText,
                                    fontSize: 12,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) {
                                  final v = addCtrls[sIdx].text.trim();
                                  if (v.isEmpty) return;
                                  checklistSetState(() {
                                    itemsState[sIdx].add(v);
                                    checksState[sIdx].add(false);
                                    addCtrls[sIdx].clear();
                                  });
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                final v = addCtrls[sIdx].text.trim();
                                if (v.isEmpty) return;
                                checklistSetState(() {
                                  itemsState[sIdx].add(v);
                                  checksState[sIdx].add(false);
                                  addCtrls[sIdx].clear();
                                });
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: GestureDetector(
                  onTap: isSaved
                      ? null
                      : () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: t.backgroundSecondary,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    AppLocalizations.t(context, 'save_to_board_title'),
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...[
                                    'Party Looks',
                                    'Occasion',
                                    'Office Fit',
                                    'Vacation',
                                  ].map(
                                    (b) => ListTile(
                                      title: Text(
                                        b,
                                        style: TextStyle(color: t.textPrimary),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: t.mutedText,
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        checklistSetState(
                                          () => _checklistSavedByTitle[title] =
                                              true,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSaved
                          ? LinearGradient(
                              colors: [t.accent.tertiary, t.accent.tertiary],
                            )
                          : LinearGradient(
                              colors: [t.accent.tertiary, t.accent.primary],
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isSaved ? AppLocalizations.t(context, 'list_saved') : AppLocalizations.t(context, 'save_to_board'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chips(AppThemeTokens t) {
    final chips = _getChipsByModule(context)[_module] ?? const <String>[];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _handleChipTap(chips[i]),
          child: _chip(chips[i], t),
        ),
      ),
    );
  }

  Widget _chip(String label, AppThemeTokens t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: t.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: t.cardBorder, width: 1.2),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: t.mutedText,
      ),
    ),
  );

  Widget _input(AppThemeTokens t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chips(t),
        AhviChatPromptBar(
          controller: _chatController,
          focusNode: _chatFocusNode,
          hintText: AppLocalizations.t(context, 'chat_hint'),
          hasTextListenable: _chatController,
          surface: t.phoneShellInner,
          border: t.cardBorder,
          accent: t.accent.primary,
          accentSecondary: t.accent.secondary,
          textHeading: t.textPrimary,
          textMuted: t.mutedText,
          shadowMedium: t.backgroundPrimary.withValues(alpha: 0.20),
          onAccent: Colors.white,
          themeTokens: t,
          onVoiceTap: _toggleListening,
          isListening: _isListening,
          onSendMessage: (v) => _sendMessage(v),
          // ── Lens sheet actions ──────────────────────────────────────
          // TODO: implement Visual Search (image picker → AI search)
          onVisualSearch: () {},
          // TODO: implement Find Similar (wardrobe → similar items screen)
          onFindSimilar: () {},
          onAddToWardrobe: null, // uses showAddToWardrobeModal default in lens sheet
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}


// ── Outfit Detail Page (Hero expand destination) ───────────────────────────

class _OutfitDetailPage extends StatefulWidget {
  final _Outfit outfit;
  final String heroTag;
  final AppThemeTokens t;
  final ValueChanged<bool> onSaveChanged;

  const _OutfitDetailPage({
    required this.outfit,
    required this.heroTag,
    required this.t,
    required this.onSaveChanged,
  });

  @override
  State<_OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<_OutfitDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.outfit.saved;
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentFade = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.2, 1.0, curve: Cubic(0.16, 1.0, 0.3, 1.0)),
    ));
    Future.delayed(const Duration(milliseconds: 170), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final accent = t.accent.primary;
    final accentTertiary = t.accent.tertiary;
    final bg = t.backgroundPrimary;
    final surface = t.phoneShellInner;
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: bg.withValues(alpha: 0.82),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent tap-through
              child: Hero(
                tag: widget.heroTag,
                flightShuttleBuilder: (_, animation, __, ___, toCtx) =>
                    AnimatedBuilder(
                      animation: animation,
                      builder: (_, __) => toCtx.widget,
                    ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: screenW * 0.88,
                    constraints: BoxConstraints(maxHeight: screenH * 0.82),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bg.withValues(alpha: 0.50),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: accent.withValues(alpha: 0.10),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Large image ───────────────────────────────────
                        SizedBox(
                          height: screenH * 0.42,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                widget.outfit.image,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Container(
                                  color: accent.withValues(alpha: 0.10),
                                  child: Icon(Icons.image_outlined,
                                      color: t.mutedText, size: 48),
                                ),
                              ),
                              // Bottom fade
                              Positioned(
                                left: 0, right: 0, bottom: 0, height: 80,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, surface],
                                    ),
                                  ),
                                ),
                              ),
                              // Top shimmer line
                              Positioned(
                                top: 0, left: 0, right: 0, height: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        accent.withValues(alpha: 0.55),
                                        accentTertiary.withValues(alpha: 0.45),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.35, 0.65, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Close button
                              Positioned(
                                top: 14, right: 14,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: bg.withValues(alpha: 0.55),
                                      border: Border.all(
                                          color: t.cardBorder, width: 1),
                                    ),
                                    child: Icon(Icons.close_rounded,
                                        color: t.textPrimary, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Content ───────────────────────────────────────
                        FadeTransition(
                          opacity: _contentFade,
                          child: SlideTransition(
                            position: _contentSlide,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(22, 6, 22, 26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tags
                                  Wrap(
                                    spacing: 6,
                                    children: widget.outfit.tags.map((tag) =>
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          border: Border.all(
                                              color: accent
                                                  .withValues(alpha: 0.20)),
                                        ),
                                        child: Text(tag,
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      ),
                                    ).toList(),
                                  ),
                                  const SizedBox(height: 10),

                                  // Name
                                  Text(
                                    widget.outfit.name,
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // 2-line description
                                  Text(
                                    widget.outfit.description.isNotEmpty
                                        ? widget.outfit.description
                                        : 'A curated look styled just for you.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.mutedText,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Save button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _saved = !_saved);
                                      widget.onSaveChanged(_saved);
                                      if (_saved) HapticFeedback.lightImpact();
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 260),
                                      curve:
                                          const Cubic(0.34, 1.56, 0.64, 1.0),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: _saved
                                            ? null
                                            : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  accent,
                                                  accentTertiary,
                                                ],
                                              ),
                                        color: _saved ? t.panel : null,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: _saved
                                            ? Border.all(
                                                color: accent
                                                    .withValues(alpha: 0.30),
                                                width: 1)
                                            : null,
                                        boxShadow: _saved
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: accent
                                                      .withValues(alpha: 0.30),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _saved
                                                ? Icons.bookmark_rounded
                                                : Icons.bookmark_border_rounded,
                                            color: _saved ? accent : onAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _saved
                                                ? 'Saved to Wardrobe'
                                                : 'Save Outfit',
                                            style: TextStyle(
                                              color:
                                                  _saved ? accent : onAccent,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated typing bubble (3 bouncing dots) ────────────────────────────────
class _PageTypingBubble extends StatefulWidget {
  const _PageTypingBubble();
  @override
  State<_PageTypingBubble> createState() => _PageTypingBubbleState();
}

class _PageTypingBubbleState extends State<_PageTypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    ));
    _anims = _ctrls.map((c) =>
      Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
    ).toList();
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.backgroundSecondary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: t.mutedText.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        )),
      ),
    );
  }
}

// ── Pulsing mic animation when listening ────────────────────────────────────
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final t = context.themeTokens;
    return ScaleTransition(
      scale: _scale,
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
// _ChatLogoHeader removed — replaced by AhviHeader (see build method above)