import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/boru_config.dart';

class BoruLivekitService {
  Future<String> getRoomToken({
    required String roomPublicId,
    required String accessToken,
  }) async {
    final roomId = Uri.encodeComponent(roomPublicId);

    final response = await http
        .post(
          Uri.parse(
            '${BoruConfig.apiBaseUrl}/livekit/rooms/$roomId/token',
          ),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz sunucu yanıtı.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'LiveKit token alınamadı.',
      );
    }

    final token = decoded['token'];

    if (token is! String || token.isEmpty) {
      throw const FormatException('LiveKit token eksik.');
    }

    final url = decoded['url'];

    if (url is String && url.startsWith('wss://')) {
      return '\$url|\$token';
    }

    return token;
  }
}
