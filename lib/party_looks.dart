import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import 'package:provider/provider.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/services/appwrite_service.dart';

class Screen4 extends StatefulWidget {
  const Screen4({super.key});

  @override
  State<Screen4> createState() => _Screen4State();
}

class _Screen4State extends State<Screen4> {
  bool _isLoading = true;
  List<Document> _boards = [];

  @override
  void initState() {
    super.initState();
    _fetchPartyBoards();
  }

  Future<void> _fetchPartyBoards() async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      // 🔥 Fetching specifically 'Party' occasion boards!
      final boards = await appwrite.getSavedBoardsByOccasion('Party');
      
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 14),
            child: Row(
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
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Party ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: 'Looks',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          color: t.accent.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Body ──
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: t.accent.primary))
                : _boards.isEmpty
                    ? _buildEmptyState(t)
                    : _buildBoardsGrid(t),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeTokens t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.panel,
              shape: BoxShape.circle,
              border: Border.all(color: t.cardBorder),
            ),
            child: Icon(Icons.celebration_rounded, size: 48, color: t.accent.secondary),
          ),
          const SizedBox(height: 24),
          Text(
            "No Party Looks Yet!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Generate style boards with the AI\nand they will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: t.mutedText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsGrid(AppThemeTokens t) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columns
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65, // Taller, Pinterest-style aspect ratio
      ),
      itemCount: _boards.length,
      itemBuilder: (context, index) {
        final board = _boards[index];
        final imageUrl = board.data['imageUrl'] ?? '';
        
        return GestureDetector(
          onTap: () {
            // TODO: Open a fullscreen view of the board, or show the items inside it!
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
              color: t.panel,
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl.isEmpty
                ? Center(child: Icon(Icons.image_not_supported, color: t.mutedText))
                : null,
          ),
        );
      },
    );
  }
}