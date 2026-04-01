import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/config/env.dart';
import 'package:myapp/services/appwrite_service.dart';

Map<String, dynamic> _parseJsonMap(String payload) =>
    Map<String, dynamic>.from(jsonDecode(payload) as Map);

String _encodeBytes(Uint8List bytes) => base64Encode(bytes);

class BackendService {
  final String baseUrl = Env.backendApiUrl;
  final AppwriteService _appwriteService = AppwriteService();

  // --- Chat & Styling Engine ---
  Future<Map<String, dynamic>> sendChatQuery(
    String query,
    String userId,
    List<Map<String, String>> chatHistory,
    String currentMemory, {
    bool isRetry = false,
    List<Map<String, dynamic>>? fetchedWardrobe,
  }) async {
    try {
      if (!isRetry) {
        print("💬 Sending message to AHVI (No wardrobe attached yet)...");
      }

      // 🚀 STRIP THE FAT: Remove the heavy image URLs before sending to FastAPI!
      final safeWardrobePayload = (fetchedWardrobe ?? []).map((item) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('image_url'); // Server only needs the text to think!
        return copy;
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/api/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': [
            ...chatHistory,
            {'role': 'user', 'content': query},
          ],
          'language': 'en',
          'current_memory': currentMemory,
          'user_profile': {},
          'wardrobe_items': safeWardrobePayload,
          'wardrobe_attached': isRetry,
        }),
      );

      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);

        // 🛑 THE PING-PONG INTERCEPTOR
        if (data['requires_wardrobe'] == true && !isRetry) {
          print("🛑 AHVI requested your wardrobe! Fetching from Appwrite...");
          final items = await _appwriteService.getWardrobeItems();

          print(
            "✅ Fetched ${items.length} items. Sending them back to AHVI...",
          );
          return sendChatQuery(
            query,
            userId,
            chatHistory,
            currentMemory,
            isRetry: true,
            fetchedWardrobe: items,
          );
        }

        // 🚀 UI LOGIC PARSING
        String rawText =
            data['message']?['content'] ??
            "I'm having trouble thinking right now.";
        String cleanText = rawText;

        List<dynamic> extractedChips = data['chips'] ?? [];
        String? extractedBoardData =
            (data['board_ids'] != null &&
                data['board_ids'].toString().isNotEmpty)
            ? data['board_ids']
            : null;
        String? extractedPackData;
        String hiddenMenuText = "";

        RegExp chipsRegex = RegExp(r'\[CHIPS:\s*(.*?)\]');
        Match? chipsMatch = chipsRegex.firstMatch(cleanText);
        if (chipsMatch != null) {
          extractedChips = chipsMatch
              .group(1)!
              .split(',')
              .map((e) => e.trim())
              .toList();
          cleanText = cleanText.replaceAll(chipsMatch.group(0)!, '').trim();
        }

        RegExp boardRegex = RegExp(r'\[STYLE_BOARD:\s*(.*?)\]');
        Match? boardMatch = boardRegex.firstMatch(cleanText);
        if (boardMatch != null) {
          extractedBoardData = boardMatch.group(1);
          cleanText = cleanText.replaceAll(boardMatch.group(0)!, '').trim();
        }

        RegExp packRegex = RegExp(r'\[PACK_LIST:\s*(.*?)\]');
        Match? packMatch = packRegex.firstMatch(cleanText);
        if (packMatch != null) {
          extractedPackData = packMatch.group(1);
          hiddenMenuText = cleanText.replaceAll(packMatch.group(0)!, '').trim();
          cleanText = "I've prepared your custom Packing Menu! 🌴✨";
        }

        data['message']['content'] = cleanText;
        data['chips'] = extractedChips;
        data['board_ids'] = extractedBoardData;
        data['pack_ids'] = extractedPackData;
        data['full_menu_text'] = hiddenMenuText;
        data['has_actions'] =
            (extractedBoardData != null || extractedPackData != null);

        return data;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      print('Backend Error: $e');
      return {'error': 'Could not connect to AHVI brain. Error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  WARDROBE: VISION & BACKGROUND REMOVAL
  // ─────────────────────────────────────────────────────────────────────────────

  Future<String?> removeBackground(String base64Image) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/remove-bg'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64Image}),
      );
      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);
        return data['image_base64'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 🚀 FIXED: Now converts Uint8List to Base64 and sends to the NEW JSON endpoint!
  Future<Map<String, dynamic>?> analyzeImage(Uint8List imageBytes) async {
    try {
      // 1. Convert the image bytes to a Base64 string
      final base64String = await compute(_encodeBytes, imageBytes);

      // 2. Point to the NEW endpoint from your vision.py router
      final uri = Uri.parse('$baseUrl/api/analyze-image');

      // 3. Send a standard JSON POST request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64String}),
      );

      if (response.statusCode == 200) {
        return await compute(_parseJsonMap, response.body);
      } else {
        print(
          "❌ Analyze API Failed: ${response.statusCode} - ${response.body}",
        );
        return null;
      }
    } catch (e) {
      print('❌ Garment Analysis Error: $e');
      return null;
    }
  }
}
