import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/boru_config.dart';

class BoruRoomsService {
  Future<List<dynamic>> getRooms() async {
    final response = await http
        .get(Uri.parse('${BoruConfig.apiBaseUrl}/rooms'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Odalar yüklenemedi: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic> && data['rooms'] is List) {
      return data['rooms'] as List;
    }

    throw const FormatException('Beklenmeyen oda listesi formatı.');
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomPublicId,
    required String accessToken,
    String? password,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${BoruConfig.apiBaseUrl}/rooms/'
        '${Uri.encodeComponent(roomPublicId)}/join',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (password != null && password.isNotEmpty)
          'password': password,
      }),
    ).timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode == 409) {
      throw Exception('Bu odanın zaten üyesisiniz.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Odaya katılım başarısız.',
      );
    }

    if (data['joined'] != true) {
      throw Exception('Odaya katılım doğrulanamadı.');
    }

    return data;
  }

  Future<void> leaveRoom({
    required String roomPublicId,
    required String accessToken,
  }) async {
    final roomId = Uri.encodeComponent(roomPublicId);

    final response = await http
        .delete(
          Uri.parse(
            '${BoruConfig.apiBaseUrl}/rooms/$roomId/leave',
          ),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Odadan ayrılma başarısız.';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['message'];
          message = detail is List
              ? detail.join(', ')
              : detail?.toString() ?? message;
        }
      } catch (_) {}

      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> _seatRequest({
    required String method,
    required String path,
    required String accessToken,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${BoruConfig.apiBaseUrl}$path');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    late http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri, headers: headers, body: jsonEncode(body ?? {}),
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      case 'PATCH':
        response = await http.patch(
          uri, headers: headers, body: jsonEncode(body ?? {}),
        );
        break;
      default:
        throw ArgumentError('Desteklenmeyen HTTP metodu.');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Koltuk işlemi başarısız.',
      );
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> getRoomSeats({
    required String roomPublicId,
    required String accessToken,
  }) async {
    final data = await _seatRequest(
      method: 'GET',
      path: '/rooms/${Uri.encodeComponent(roomPublicId)}/seats',
      accessToken: accessToken,
    );

    final seats = data['seats'];
    if (seats is! List) {
      throw const FormatException('Koltuk listesi alınamadı.');
    }

    return seats
        .whereType<Map>()
        .map((seat) => Map<String, dynamic>.from(seat))
        .toList();
  }

  Future<Map<String, dynamic>> sitOnSeat({
    required String roomPublicId,
    required int seatNumber,
    required String accessToken,
  }) {
    return _seatRequest(
      method: 'POST',
      path: '/rooms/${Uri.encodeComponent(roomPublicId)}/seats/$seatNumber/sit',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> leaveSeat({
    required String roomPublicId,
    required String accessToken,
  }) {
    return _seatRequest(
      method: 'DELETE',
      path: '/rooms/${Uri.encodeComponent(roomPublicId)}/seats/leave',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> setSeatLock({
    required String roomPublicId,
    required int seatNumber,
    required String accessToken,
    required bool isLocked,
  }) {
    return _seatRequest(
      method: 'PATCH',
      path: '/rooms/${Uri.encodeComponent(roomPublicId)}/seats/$seatNumber/lock',
      accessToken: accessToken,
      body: {'isLocked': isLocked},
    );
  }

}
