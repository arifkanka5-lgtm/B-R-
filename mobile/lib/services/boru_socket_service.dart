import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/boru_config.dart';

class BoruSocketService {
  io.Socket? _socket;

  void connect({
    required String roomPublicId,
    required String accessToken,
    required void Function(Map<String, dynamic>) onSeats,
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(String) onError,
  }) {
    disconnect();

    final socket = io.io(
      '${BoruConfig.apiBaseUrl}/rooms',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      socket.emit('room:join', {
        'roomPublicId': roomPublicId,
      });
    });

    socket.on('room:seats', (dynamic data) {
      if (data is Map) {
        onSeats(Map<String, dynamic>.from(data));
      }
    });

    socket.on('room:message', (dynamic data) {
      if (data is Map) onMessage(Map<String, dynamic>.from(data));
    });

    socket.on('room:error', (dynamic data) {
      if (data is Map) {
        onError(data['message']?.toString() ?? 'Oda işlemi başarısız.');
      }
    });

    socket.connect();
  }

  void sendMessage({required String roomPublicId, required String text}) {
    if (_socket?.connected != true) {
      throw StateError('Sohbet bağlantısı kurulamadı. Tekrar deneyin.');
    }
    _socket!.emit('room:message', {
      'roomPublicId': roomPublicId,
      'text': text,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
