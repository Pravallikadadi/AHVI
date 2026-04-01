import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';
import 'package:myapp/widgets/ahvi_lens_sheet.dart';
import 'package:myapp/theme/theme_tokens.dart';

Future<void> showAhviStylistChatSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.88,
      child: const _AhviStylistChatSheet(),
    ),
  );
}

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
              colors: [
                t.accent.secondary,
                t.accent.primary,
              ],
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
                child: const Text(
                  '✦',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask AHVI',
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

// ─── CHAT HISTORY MODEL ───────────────────────────────────────────────────────
class _ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<_SheetMessage> messages;

  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

class _AhviStylistChatSheet extends StatefulWidget {
  const _AhviStylistChatSheet();

  @override
  State<_AhviStylistChatSheet> createState() => _AhviStylistChatSheetState();
}

class _AhviStylistChatSheetState extends State<_AhviStylistChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_SheetMessage> _messages = [];
  bool _typing = false;
  bool _showPrompts = true;
  bool _chatHasText = false;

  // ── History ─────────────────────────────────────────────────────────
  final List<_ChatSession> _history = [];
  String? _currentSessionId;

  final List<String> _quickPrompts = const [
    'What should I wear today?',
    'Style tips for tonight',
    'Build a minimal routine',
    'Help me plan my day',
    'Smart tips for this week',
  ];

  @override
  void initState() {
    super.initState();
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _chatHasText && mounted) {
        setState(() => _chatHasText = hasText);
      }
    });
    Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _messages.isNotEmpty) return;
      setState(() {
        _messages.add(
          _SheetMessage(
            text:
                "Hi! I'm AHVI, your personal AI stylist ✦\n\nAsk me about outfit ideas, routines, planning, or daily recommendations.",
            isUser: false,
          ),
        );
      });
    });
  }

  void _saveCurrentSession() {
    if (_messages.isEmpty) return;
    final userMessages = _messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;
    final title = userMessages.first.text.length > 40
        ? '${userMessages.first.text.substring(0, 40)}…'
        : userMessages.first.text;
    final existingIdx = _history.indexWhere((s) => s.id == _currentSessionId);
    final session = _ChatSession(
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
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _showPrompts = true;
      _chatHasText = false;
      _inputController.clear();
      _messages.add(
        _SheetMessage(
          text:
              "Hi! I'm AHVI, your personal AI stylist ✦\n\nAsk me about outfit ideas, routines, planning, or daily recommendations.",
          isUser: false,
        ),
      );
    });
  }

  void _loadSession(_ChatSession session) {
    _saveCurrentSession();
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _currentSessionId = session.id;
      _messages
        ..clear()
        ..addAll(session.messages);
      _showPrompts = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _typing) return;
    _inputController.clear();
    setState(() {
      _showPrompts = false;
      _typing = true;
      _messages.add(_SheetMessage(text: trimmed, isUser: true));
    });
    _scrollToBottom();

    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_SheetMessage(text: _buildReply(trimmed), isUser: false));
      });
      _scrollToBottom();
      _saveCurrentSession();
    });
  }

  String _buildReply(String query) {
    final q = query.toLowerCase();
    if (q.contains('wear') || q.contains('outfit')) {
      return 'Go for a clean base and one accent layer. Keep colors coordinated and match footwear to the occasion.';
    }
    if (q.contains('routine') || q.contains('skin')) {
      return 'Keep it simple and consistent: cleanse, targeted treatment, moisturize, and SPF in daytime.';
    }
    if (q.contains('plan') || q.contains('meal') || q.contains('workout')) {
      return 'Start with your top 3 priorities today, then build around time blocks so your plan stays realistic.';
    }
    return 'Great question. Tell me your goal and context, and I will give you a concise personalized recommendation.';
  }

  Widget _historyDrawer() {
    final t = context.themeTokens;
    return Drawer(
      backgroundColor: t.backgroundPrimary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
              child: Row(children: [
                Text(
                  'Chats',
                  style: GoogleFonts.anton(
                    fontSize: 20,
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('New', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Divider(color: t.cardBorder, height: 1),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Text(
                        'No chats yet.\nStart a conversation!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.mutedText, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _history.length,
                      separatorBuilder: (_, _) => Divider(color: t.cardBorder, height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (ctx, i) {
                        final session = _history[i];
                        final isActive = session.id == _currentSessionId;
                        return GestureDetector(
                          onTap: () => _loadSession(session),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            color: isActive ? t.accent.primary.withValues(alpha: 0.08) : Colors.transparent,
                            child: Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? t.accent.primary.withValues(alpha: 0.15)
                                      : t.panel,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive ? t.accent.primary.withValues(alpha: 0.4) : t.cardBorder,
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
                                  width: 6, height: 6,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      drawer: _historyDrawer(),
      body: Container(
      decoration: BoxDecoration(
        color: t.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.panelBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [t.accent.primary, t.accent.tertiary],
                    ),
                  ),
                  child: const Center(
                    child: Text('✦', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AHVI',
                        style: GoogleFonts.anton(
                          fontSize: 19,
                          color: t.textPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        'Your personal AI stylist',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
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
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                ..._messages.map((msg) => _Bubble(msg: msg)),
                if (_typing) _TypingBubble(color: t.accent.secondary),
              ],
            ),
          ),
          if (_showPrompts)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _sendMessage(_quickPrompts[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Text(
                      _quickPrompts[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: t.accent.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _quickPrompts.length,
              ),
            ),
          Container(
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: t.phoneShellInner,
              border: Border(top: BorderSide(color: t.cardBorder)),
            ),
            child: AhviChatPromptBar(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              controller: _inputController,
              focusNode: _inputFocusNode,
              hintText: 'Ask your stylist...',
              hasText: _chatHasText,
              surface: t.phoneShellInner,
              border: t.cardBorder,
              accent: t.accent.primary,
              accentSecondary: t.accent.secondary,
              textHeading: t.textPrimary,
              textMuted: t.mutedText,
              shadowMedium: t.backgroundPrimary.withValues(alpha: 0.20),
              onAccent: Colors.white,
              onSubmitted: (value) => _sendMessage(value),
              onSend: () => _sendMessage(_inputController.text),
              onEmptySend: () {},
              onAddTap: () => showAhviLensSheet(
                context,
                t: context.themeTokens,
              ),
            ),
          ),
        ],
      ),
    ), // Container (body)
    ); // Scaffold
  }
}

class _SheetMessage {
  final String text;
  final bool isUser;

  _SheetMessage({required this.text, required this.isUser});
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: msg.isUser
              ? t.accent.primary.withValues(alpha: 0.12)
              : t.panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: Border.all(
            color: msg.isUser
                ? t.accent.primary.withValues(alpha: 0.35)
                : t.cardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(color: t.textPrimary, fontSize: 12, height: 1.45),
        ),
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
          borderRadius: BorderRadius.circular(16),
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