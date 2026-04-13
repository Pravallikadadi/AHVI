// ═══════════════════════════════════════════════════════════════
//  Ahvi_plus_button_full.dart
//  ChatGPT-style Plus Button — 4 Features Fully Implemented
//
//  Features:
//    1. Camera       — rear camera తో photo తీయడం
//    2. Photo Library — gallery నుండి image pick చేయడం
//    3. Files        — PDF, DOCX, CSV, XLSX, etc. pick చేయడం
//    4. Web Search   — bottom sheet లో search చేసి pending గా set చేయడం
//
//  HOW TO USE:
//    1. final _plusCtrl = ChatPlusButtonController();
//    2. dispose లో: _plusCtrl.dispose(); _removeOverlay();
//    3. Input row లో:
//         ChatPlusButton(controller: _plusCtrl)
//    4. Pending attachment చూడడానికి:
//         _plusCtrl.pendingAttachment  (Attachment? object)
//    5. Send తర్వాత:
//         _plusCtrl.clearPendingAttachment();
//
//  pubspec.yaml dependencies:
//    image_picker: ^1.0.7
//    file_picker: ^6.1.1
//    url_launcher: ^6.2.5
//    mime: ^1.0.5
//    camera: ^0.10.5+9
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'package:myapp/app_localizations.dart';
import 'package:camera/camera.dart';

// ───────────────────────────────────────────────────────────
// Attachment model
// ───────────────────────────────────────────────────────────

class Attachment {
  final String label;
  final File? file;
  final String? mimeType;
  final bool isWebSearch;
  final String? searchQuery; // Google URL

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

  Color get accentColor {
    if (isWebSearch) return const Color(0xFF10A37F);
    if (isImage) return const Color(0xFF3B6D11);
    final m = mimeType ?? lookupMimeType(file?.path ?? '') ?? '';
    if (m.contains('pdf')) return const Color(0xFF993C1D);
    return const Color(0xFF185FA5);
  }

  Color get bgColor {
    if (isWebSearch) return const Color(0xFFE6F7F3);
    if (isImage) return const Color(0xFFEAF3DE);
    final m = mimeType ?? lookupMimeType(file?.path ?? '') ?? '';
    if (m.contains('pdf')) return const Color(0xFFFAECE7);
    return const Color(0xFFE6F1FB);
  }
}

// ───────────────────────────────────────────────────────────
// ChatPlusButtonController
// ───────────────────────────────────────────────────────────

class ChatPlusButtonController extends ChangeNotifier {
  final _picker = ImagePicker();

  bool _menuOpen = false;
  Attachment? _pending;

  bool get menuOpen => _menuOpen;
  Attachment? get pendingAttachment => _pending;

  // ── Menu open/close ───────────────────────────────────────

  void toggleMenu(BuildContext context) {
    _menuOpen = !_menuOpen;
    if (_menuOpen) FocusScope.of(context).unfocus();
    notifyListeners();
  }

  void closeMenu() {
    if (_menuOpen) {
      _menuOpen = false;
      notifyListeners();
    }
  }

  // ── Attachment helpers ────────────────────────────────────

  void clearPendingAttachment() {
    _pending = null;
    notifyListeners();
  }

  void _set(Attachment a) {
    _pending = a;
    notifyListeners();
  }

  // ── 1. Camera ─────────────────────────────────────────────

  Future<void> capturePhoto(BuildContext context) async {
    closeMenu();
    _removeOverlay();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _err(context, AppLocalizations.t(context, 'plus_err_camera'));
        return;
      }
      final result = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          builder: (_) => _AhviCameraScreen(cameras: cameras),
          fullscreenDialog: true,
        ),
      );
      if (result == null) return;
      _set(Attachment(
        label: 'Photo_\${DateTime.now().millisecondsSinceEpoch}.jpg',
        file: result,
        mimeType: lookupMimeType(result.path) ?? 'image/jpeg',
      ));
    } catch (_) {
      _err(context, AppLocalizations.t(context, 'plus_err_camera'));
    }
  }

  // ── 2. Photo Library ─────────────────────────────────────

  Future<void> pickPhoto(BuildContext context) async {
    closeMenu();
    _removeOverlay();
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xfile == null) return;
      _set(Attachment(
        label: xfile.name,
        file: File(xfile.path),
        mimeType: lookupMimeType(xfile.path) ?? 'image/jpeg',
      ));
    } catch (_) {
      _err(context, AppLocalizations.t(context, 'plus_err_photo'));
    }
  }

  // ── 3. Files ─────────────────────────────────────────────

  Future<void> pickFile(BuildContext context) async {
    closeMenu();
    _removeOverlay();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'docx', 'doc', 'txt',
          'csv', 'xlsx', 'xls', 'pptx',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.first;
      if (pf.path == null) return;
      _set(Attachment(
        label: pf.name,
        file: File(pf.path!),
        mimeType: lookupMimeType(pf.path!) ?? 'application/octet-stream',
      ));
    } catch (_) {
      _err(context, AppLocalizations.t(context, 'plus_err_file'));
    }
  }

  // ── 4. Web Search ─────────────────────────────────────────

  void openWebSearch(BuildContext context) {
    closeMenu();
    _removeOverlay();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WebSearchSheet(
        onSearch: (query) {
          Navigator.pop(ctx);
          _set(Attachment(
            label: '${AppLocalizations.t(context, 'plus_search_label')}: "$query"',
            isWebSearch: true,
            searchQuery:
                'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
          ));
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Open attachment (tap on chip) ─────────────────────────

  Future<void> openAttachment(Attachment att) async {
    if (att.isWebSearch && att.searchQuery != null) {
      final uri = Uri.parse(att.searchQuery!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _err(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────
// Overlay helpers (global)
// ───────────────────────────────────────────────────────────

final LayerLink _overlayLink = LayerLink();
OverlayEntry? _overlayEntry;

void _showOverlay(
  BuildContext context,
  ChatPlusButtonController ctrl, {
  Color panelColor = Colors.white,
  Color borderColor = const Color(0xFFE0E0E0),
  Color textColor = const Color(0xFF1C1C1E),
}) {
  _removeOverlay();
  _overlayEntry = OverlayEntry(
    builder: (ctx) => _ChatPlusPopup(
      link: _overlayLink,
      controller: ctrl,
      panelColor: panelColor,
      borderColor: borderColor,
      textColor: textColor,
      onDismiss: () {
        ctrl.closeMenu();
        _removeOverlay();
      },
    ),
  );
  Overlay.of(context).insert(_overlayEntry!);
}

void _removeOverlay() {
  _overlayEntry?.remove();
  _overlayEntry = null;
}

// ───────────────────────────────────────────────────────────
// ChatPlusButton
// ───────────────────────────────────────────────────────────

class ChatPlusButton extends StatelessWidget {
  final ChatPlusButtonController controller;

  /// Accent color for button bg highlight and border when open.
  /// Defaults to a neutral grey — pass your theme accent for full theming.
  final Color accentColor;

  /// Panel background color for the popup card (e.g. theme.panel).
  final Color panelColor;

  /// Border color for the popup card (e.g. theme.cardBorder).
  final Color borderColor;

  /// Text color used inside popup rows (e.g. theme.textPrimary).
  final Color textColor;

  /// Button size (default 38 — matches AhviChatPromptBar)
  final double buttonSize;

  /// Border radius of button (default 13)
  final double buttonRadius;

  const ChatPlusButton({
    super.key,
    required this.controller,
    this.accentColor = const Color(0xFF10A37F),
    this.panelColor = Colors.white,
    this.borderColor = const Color(0xFFE0E0E0),
    this.textColor = const Color(0xFF1C1C1E),
    this.buttonSize = 38,
    this.buttonRadius = 13,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return CompositedTransformTarget(
          link: _overlayLink,
          child: GestureDetector(
            onTap: () {
              if (controller.menuOpen) {
                controller.closeMenu();
                _removeOverlay();
              } else {
                controller.toggleMenu(context);
                _showOverlay(
                  context,
                  controller,
                  panelColor: panelColor,
                  borderColor: borderColor,
                  textColor: textColor,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: controller.menuOpen
                    ? accentColor.withValues(alpha: 0.20)
                    : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(buttonRadius),
                border: Border.all(
                  color: controller.menuOpen
                      ? accentColor.withValues(alpha: 0.45)
                      : accentColor.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: AnimatedRotation(
                turns: controller.menuOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────
// Popup overlay — ChatGPT style list
// ───────────────────────────────────────────────────────────

class _ChatPlusPopup extends StatefulWidget {
  final LayerLink link;
  final ChatPlusButtonController controller;
  final VoidCallback onDismiss;
  // Theme colors passed from ChatPlusButton
  final Color panelColor;
  final Color borderColor;
  final Color textColor;

  const _ChatPlusPopup({
    required this.link,
    required this.controller,
    required this.onDismiss,
    required this.panelColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  State<_ChatPlusPopup> createState() => _ChatPlusPopupState();
}

class _ChatPlusPopupState extends State<_ChatPlusPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
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
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
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
              child: _buildCard(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2E3352) : const Color(0xFFE0E0E0);
    final labelColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    // Skincare-style colored icon squares — same as _SkincarePlusMenuRow
    final items = [
      _Item(
        icon: Icons.camera_alt_rounded,
        label: AppLocalizations.t(context, 'plus_menu_camera'),
        color: const Color(0xFFFF6B6B),
        onTap: () => widget.controller.capturePhoto(context),
      ),
      _Item(
        icon: Icons.photo_library_rounded,
        label: AppLocalizations.t(context, 'plus_menu_photo_library'),
        color: const Color(0xFF4ECDC4),
        onTap: () => widget.controller.pickPhoto(context),
      ),
      _Item(
        icon: Icons.folder_rounded,
        label: AppLocalizations.t(context, 'plus_menu_files'),
        color: const Color(0xFF45B7D1),
        onTap: () => widget.controller.pickFile(context),
      ),
      _Item(
        icon: Icons.travel_explore_rounded,
        label: AppLocalizations.t(context, 'plus_menu_search'),
        color: const Color(0xFF96CEB4),
        onTap: () => widget.controller.openWebSearch(context),
      ),
    ];

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map((item) => _SkincarePlusMenuRow(
                    icon: item.icon,
                    label: item.label,
                    color: item.color,
                    textColor: labelColor,
                    onTap: () {
                      widget.onDismiss();
                      item.onTap();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label, required this.color, required this.onTap});
}

// ── Skincare-style menu row with colored icon square + hover ─────────────────
class _SkincarePlusMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _SkincarePlusMenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_SkincarePlusMenuRow> createState() => _SkincarePlusMenuRowState();
}

class _SkincarePlusMenuRowState extends State<_SkincarePlusMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) {
        setState(() => _hovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.color.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────
// ChatAttachmentChip — pending attachment preview
// Place ABOVE the input Row in your Column
// ───────────────────────────────────────────────────────────

class ChatAttachmentChip extends StatelessWidget {
  final ChatPlusButtonController controller;

  const ChatAttachmentChip({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final att = controller.pendingAttachment;
        if (att == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: () => controller.openAttachment(att),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            decoration: BoxDecoration(
              color: isDark
                  ? att.accentColor.withOpacity(0.12)
                  : att.bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: att.accentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                // Image thumbnail or icon
                if (att.isImage && att.file != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: Image.file(
                      att.file!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: att.accentColor.withOpacity(0.12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child:
                        Icon(att.icon, color: att.accentColor, size: 28),
                  ),

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        att.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: att.accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        att.isWebSearch
                            ? AppLocalizations.t(context, 'plus_chip_open_browser')
                            : att.isImage
                                ? AppLocalizations.t(context, 'plus_chip_image_view')
                                : AppLocalizations.t(context, 'plus_chip_file_attached'),
                        style: TextStyle(
                          fontSize: 11,
                          color: att.accentColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: att.accentColor),
                  onPressed: controller.clearPendingAttachment,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────
// Web Search Bottom Sheet
// ───────────────────────────────────────────────────────────

class _WebSearchSheet extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onCancel;

  const _WebSearchSheet({required this.onSearch, required this.onCancel});

  @override
  State<_WebSearchSheet> createState() => _WebSearchSheetState();
}

class _WebSearchSheetState extends State<_WebSearchSheet> {
  final _ctrl = TextEditingController();

  List<String> _suggestions(BuildContext context) => [
    AppLocalizations.t(context, 'plus_suggestion_1'),
    AppLocalizations.t(context, 'plus_suggestion_2'),
    AppLocalizations.t(context, 'plus_suggestion_3'),
    AppLocalizations.t(context, 'plus_suggestion_4'),
    AppLocalizations.t(context, 'plus_suggestion_5'),
    AppLocalizations.t(context, 'plus_suggestion_6'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF10A37F);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textMuted = isDark ? const Color(0xFF8A8FA8) : Colors.grey;
    final fieldBg = isDark ? const Color(0xFF252840) : Colors.white;
    final fieldBorder = isDark ? const Color(0xFF2E3352) : const Color(0xFFE0E0E0);
    final chipBg = isDark ? const Color(0xFF1A3D33) : const Color(0xFFE6F7F3);
    final disabledBg = isDark ? const Color(0xFF252840) : Colors.grey.shade200;
    final iconCircleBg = isDark ? const Color(0xFF1A3D33) : const Color(0xFFE6F7F3);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconCircleBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.travel_explore,
                      color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Text(AppLocalizations.t(context, 'plus_web_search_title'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                const Spacer(),
                IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: widget.onCancel),
              ],
            ),
            const SizedBox(height: 14),

            // Search field
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: textPrimary),
              onChanged: (_) => setState(() {}),
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: AppLocalizations.t(context, 'plus_web_search_hint'),
                hintStyle: TextStyle(color: textMuted),
                prefixIcon: const Icon(Icons.search, color: accent),
                filled: true,
                fillColor: fieldBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: fieldBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 1.5),
                ),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: textMuted),
                        onPressed: () => setState(() => _ctrl.clear()),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Suggestions
            Text(AppLocalizations.t(context, 'plus_web_suggestions'),
                style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions(context)
                  .map((s) => GestureDetector(
                        onTap: () => widget.onSearch(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: accent.withOpacity(0.3)),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: accent)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),

            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _ctrl.text.trim().isNotEmpty
                    ? () => widget.onSearch(_ctrl.text.trim())
                    : null,
                icon: const Icon(Icons.search),
                label: Text(AppLocalizations.t(context, 'plus_web_search_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: disabledBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  USAGE EXAMPLE
// ═══════════════════════════════════════════════════════════════

/*

class _MyChatState extends State<MyChatScreen> {
  final _plusCtrl = ChatPlusButtonController();
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _plusCtrl.dispose();
    _textCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    final att  = _plusCtrl.pendingAttachment;
    if (text.isEmpty && att == null) return;
    _textCtrl.clear();
    _plusCtrl.clearPendingAttachment();
    // ... your send logic ...
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _plusCtrl.closeMenu(); _removeOverlay(); },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(child: ListView(...)),

            // Attachment preview (above input)
            ChatAttachmentChip(controller: _plusCtrl),

            // Input row
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ChatPlusButton(controller: _plusCtrl),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(hintText: 'Message...'),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

*/
// ═══════════════════════════════════════════════════════════════
//  _AhviCameraScreen — in-app camera with live preview
// ═══════════════════════════════════════════════════════════════

class _AhviCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _AhviCameraScreen({required this.cameras});

  @override
  State<_AhviCameraScreen> createState() => _AhviCameraScreenState();
}

class _AhviCameraScreenState extends State<_AhviCameraScreen>
    with WidgetsBindingObserver {
  late CameraController _ctrl;
  bool _initialized = false;
  bool _capturing = false;
  int _cameraIndex = 0; // 0 = rear, tries front if available
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Prefer rear camera
    _cameraIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_cameraIndex < 0) _cameraIndex = 0;
    _initCamera(_cameraIndex);
  }

  Future<void> _initCamera(int index) async {
    final ctrl = CameraController(
      widget.cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      await ctrl.setFlashMode(_flashMode);
      if (!mounted) return;
      setState(() {
        _ctrl = ctrl;
        _initialized = true;
      });
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_initialized) _ctrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (!_initialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final xfile = await _ctrl.takePicture();
      if (mounted) Navigator.of(context).pop(File(xfile.path));
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    if (!_initialized) return;
    final next = _flashMode == FlashMode.off
        ? FlashMode.auto
        : _flashMode == FlashMode.auto
            ? FlashMode.always
            : FlashMode.off;
    await _ctrl.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    _initialized = false;
    await _ctrl.dispose();
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _initCamera(_cameraIndex);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.always: return Icons.flash_on_rounded;
      case FlashMode.off:    return Icons.flash_off_rounded;
      default:               return Icons.flash_auto_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──
          if (_initialized)
            Center(
              child: AspectRatio(
                aspectRatio: _ctrl.value.aspectRatio,
                child: CameraPreview(_ctrl),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // ── Top bar: close + flash ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close
                  _CamBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  // Flash toggle
                  _CamBtn(
                    icon: _flashIcon,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom bar: flip + shutter ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Flip camera
                    _CamBtn(
                      icon: Icons.flip_camera_ios_rounded,
                      onTap: widget.cameras.length > 1 ? _flipCamera : null,
                      size: 44,
                    ),

                    // Shutter
                    GestureDetector(
                      onTap: _capture,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _capturing ? 68 : 72,
                        height: _capturing ? 68 : 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white38, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.25),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: _capturing
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black54,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // Spacer to balance flip button
                    const SizedBox(width: 44, height: 44),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small circular button used in camera UI ──
class _CamBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const _CamBtn({required this.icon, this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}