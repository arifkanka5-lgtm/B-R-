import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class BoruGiftService {
  static final Random _random = Random.secure();

  static String createRequestId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    return 'gift_${timestamp}_$randomPart';
  }

  static Future<Map<String, dynamic>> sendGift({
    required String apiBaseUrl,
    required String accessToken,
    required String roomPublicId,
    required String receiverPublicId,
    required String giftCode,
    int quantity = 1,
    required String requestId,
  }) async {
    if (receiverPublicId.trim().isEmpty) {
      throw Exception('Hediye alıcısı seçilmedi.');
    }

    if (quantity < 1 || quantity > 100) {
      throw Exception('Hediye miktarı 1-100 arasında olmalı.');
    }

    final base = apiBaseUrl.replaceAll(RegExp(r'/$'), '');

    final response = await http
        .post(
          Uri.parse('$base/gifts/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'receiverPublicId': receiverPublicId,
            'roomPublicId': roomPublicId,
            'giftCode': giftCode,
            'quantity': quantity,
            'requestId': requestId,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];

      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Hediye gönderilemedi.',
      );
    }

    if (data['status'] != 'SUCCESS' && data['status'] != 'ALREADY_PROCESSED') {
      throw Exception('Beklenmeyen gönderim sonucu.');
    }

    return data;
  }
}
