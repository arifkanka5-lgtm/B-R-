import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/boru_config.dart';

class BoruSocketService {
  io.Socket? _socket;

  void connect({
    required String roomPublicId,
    required String accessToken,
    required void Function(Map<String, dynamic>) onSeats,
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

    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
