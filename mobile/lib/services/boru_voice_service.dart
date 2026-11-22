import 'package:livekit_client/livekit_client.dart' as lk;

import '../core/boru_config.dart';

class BoruVoiceService {
  lk.Room? _room;

  lk.Room? get room => _room;

  bool get isConnected =>
      _room?.connectionState == lk.ConnectionState.connected;

  Future<lk.Room> connect({
    required String token,
  }) async {
    if (_room != null) {
      await disconnect();
    }

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    try {
      await room.connect(
        BoruConfig.livekitUrl,
        token,
      );

      _room = room;
      return room;
    } catch (_) {
      await room.dispose();
      rethrow;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final room = _room;

    if (room == null || !isConnected) {
      throw StateError('Sesli odaya bağlı değilsiniz.');
    }

    await room.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;

    if (room == null) return;

    try {
      await room.disconnect();
    } finally {
      await room.dispose();
    }
  }
}
