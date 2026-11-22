import '../core/boru_config.dart';
import 'boru_gift_shop.dart';
import 'boru_user_profile.dart';
import 'boru_room_chat_sheet.dart';
import '../widgets/boru_role_badge.dart';
import '../theme/boru_theme.dart';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/boru_livekit_service.dart';
import '../services/boru_rooms_service.dart';
import '../services/boru_voice_service.dart';
import '../services/boru_socket_service.dart';

class BoruVoiceRoomPage extends StatefulWidget {
  const BoruVoiceRoomPage({
    super.key,
    required this.roomPublicId,
    required this.roomName,
    required this.accessToken,
    required this.currentUserPublicId,
  });

  final String roomPublicId;
  final String roomName;
  final String accessToken;
  final String currentUserPublicId;

  @override
  State<BoruVoiceRoomPage> createState() => _BoruVoiceRoomPageState();
}

class _BoruSeatPalette {
  final Color background;
  final Color occupied;
  final Color selected;
  final Color locked;
  final Color border;
  final Color selectedBorder;
  final Color occupiedBorder;
  final Color avatar;
  final Color accent;
  final Color glow;

  const _BoruSeatPalette({
    required this.background,
    required this.occupied,
    required this.selected,
    required this.locked,
    required this.border,
    required this.selectedBorder,
    required this.occupiedBorder,
    required this.avatar,
    required this.accent,
    required this.glow,
  });
}

class _BoruVoiceRoomPageState extends State<BoruVoiceRoomPage> {
  final voiceService = BoruVoiceService();
  final tokenService = BoruLivekitService();
  final roomsService = BoruRoomsService();
  final socketService = BoruSocketService();
  final ValueNotifier<List<Map<String, dynamic>>> chatMessages = ValueNotifier([]);

  lk.EventsListener<lk.RoomEvent>? roomListener;

  List<Map<String, dynamic>> seats = [];

  bool connecting = true;
  bool microphoneEnabled = false;
  bool leaving = false;
  bool seatsLoading = true;
  int roomThemeLevel = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    connectToRoom();
  }

  Future<void> connectToRoom() async {
    try {
      final token = await tokenService.getRoomToken(
        roomPublicId: widget.roomPublicId,
        accessToken: widget.accessToken,
      );

      if (!mounted || leaving) return;

      final room = await voiceService.connect(token: token);

      roomListener = room.createListener()
        ..on<lk.ParticipantConnectedEvent>((event) {
          if (mounted && !leaving) {
            setState(() {});
            _refreshSeats(showLoading: false);
          }
        })
        ..on<lk.ParticipantDisconnectedEvent>((event) {
          if (mounted && !leaving) {
            setState(() {});
            _refreshSeats(showLoading: false);
          }
        });

      if (!mounted || leaving) {
        await voiceService.disconnect();
        return;
      }

      setState(() {
        connecting = false;
        error = null;
      });

      await _refreshSeats();

      socketService.connect(
        roomPublicId: widget.roomPublicId,
        accessToken: widget.accessToken,
        onSeats: (data) {
          final rawSeats = data['seats'];

          if (!mounted || rawSeats is! List) return;

          setState(() {
            seats = rawSeats
                .whereType<Map>()
                .map((seat) => Map<String, dynamic>.from(seat))
                .toList();
            seatsLoading = false;
          });
        },
        onMessage: (message) {
          if (!mounted || leaving) return;
          final next = [...chatMessages.value, message];
          chatMessages.value = next.length > 100
              ? next.sublist(next.length - 100)
              : next;
        },
        onError: _message,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        connecting = false;
        error = e.toString();
      });
    }
  }

  Future<void> _refreshSeats({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => seatsLoading = true);
    }

    try {
      final result = await roomsService.getRoomSeats(
        roomPublicId: widget.roomPublicId,
        accessToken: widget.accessToken,
      );

      if (!mounted) return;

      setState(() {
        seats = result;
        seatsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => seatsLoading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Koltuklar yüklenemedi: $e')));
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUserProfile(String userPublicId) async {
    if (!mounted || userPublicId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BoruUserProfilePage(
          userPublicId: userPublicId,
          accessToken: widget.accessToken,
          roomPublicId: widget.roomPublicId,
          currentUserPublicId: widget.currentUserPublicId,
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF171229),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.60,
          child: BoruRoomChatSheet(
            messages: chatMessages,
            currentUserPublicId: widget.currentUserPublicId,
            onSend: (text) => socketService.sendMessage(
              roomPublicId: widget.roomPublicId,
              text: text,
            ),
            onOpenProfile: _openUserProfile,
          ),
        ),
      ),
    );
  }

  Future<void> _leaveMySeat() async {
    try {
      await roomsService.leaveSeat(
        roomPublicId: widget.roomPublicId,
        accessToken: widget.accessToken,
      );
      await _refreshSeats(showLoading: false);
      _message('Mikrofon koltuğundan kalktınız.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _handleSeatTap(Map<String, dynamic> seat) async {
    if (leaving) return;
    final userPublicId = seat['userPublicId']?.toString();
    if (userPublicId != null && userPublicId.isNotEmpty) {
      await _openUserProfile(userPublicId);
      return;
    }

    if (seat['isLocked'] == true) {
      _message('Bu koltuk kilitli.');
      return;
    }

    try {
      final seatNumber = seat['seatNumber'] as int;
      await roomsService.sitOnSeat(
        roomPublicId: widget.roomPublicId,
        seatNumber: seatNumber,
        accessToken: widget.accessToken,
      );
      await _refreshSeats(showLoading: false);
      _message('$seatNumber numaralı koltuğa oturdunuz.');
    } catch (error) {
      _message(error.toString());
      await _refreshSeats(showLoading: false);
    }
  }

  Future<void> _toggleSeatLock(Map<String, dynamic> seat) async {
    final seatNumber = seat['seatNumber'] as int;
    final isLocked = seat['isLocked'] == true;

    if (!isLocked && seat['userPublicId'] != null) {
      _message('Dolu koltuk kilitlenemez.');
      return;
    }

    try {
      await roomsService.setSeatLock(
        roomPublicId: widget.roomPublicId,
        seatNumber: seatNumber,
        accessToken: widget.accessToken,
        isLocked: !isLocked,
      );

      await _refreshSeats(showLoading: false);
      _message(isLocked ? 'Koltuk açıldı.' : 'Koltuk kilitlendi.');
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> toggleMicrophone() async {
    try {
      final nextValue = !microphoneEnabled;

      if (nextValue) {
        final permission = await Permission.microphone.request();

        if (!permission.isGranted) {
          throw Exception('Mikrofon izni verilmedi.');
        }
      }

      await voiceService.setMicrophoneEnabled(nextValue);

      if (!mounted) return;

      setState(() => microphoneEnabled = nextValue);
    } catch (e) {
      _message(e.toString());
    }
  }

  Future<void> leaveRoom() async {
    if (leaving) return;

    setState(() => leaving = true);

    try {
      // Önce koltuğu boşalt.
      try {
        await roomsService.leaveSeat(
          roomPublicId: widget.roomPublicId,
          accessToken: widget.accessToken,
        );
      } catch (_) {}

      await voiceService.disconnect();

      await roomsService.leaveRoom(
        roomPublicId: widget.roomPublicId,
        accessToken: widget.accessToken,
      );

      if (!mounted) return;

      socketService.disconnect();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() => leaving = false);
      _message('Odadan çıkış hatası: $e');
    }
  }

  _BoruSeatPalette _themeForLevel(int level) {
    switch (level) {
      case 1:
        return const _BoruSeatPalette(
          background: Color(0xFF102B49),
          occupied: Color(0xFF174B70),
          selected: Color(0xFF155E75),
          locked: Color(0xFF493B24),
          border: Color(0xFF3676A8),
          selectedBorder: Color(0xFFFFD700),
          occupiedBorder: Color(0xFF62C8FF),
          avatar: Color(0xFF205C88),
          accent: Color(0xFFFFD700),
          glow: Color(0x553BAEFF),
        );
      case 2:
        return const _BoruSeatPalette(
          background: Color(0xFF3B111D),
          occupied: Color(0xFF681B2C),
          selected: Color(0xFF81202E),
          locked: Color(0xFF493321),
          border: Color(0xFFB52E42),
          selectedBorder: Color(0xFFFFD700),
          occupiedBorder: Color(0xFFFFB347),
          avatar: Color(0xFF862D42),
          accent: Color(0xFFFFD700),
          glow: Color(0x88FF3D57),
        );
      case 3:
        return const _BoruSeatPalette(
          background: Color(0xFF21103E),
          occupied: Color(0xFF392064),
          selected: Color(0xFF51278A),
          locked: Color(0xFF493321),
          border: Color(0xFF9864E8),
          selectedBorder: Color(0xFFFFD700),
          occupiedBorder: Color(0xFFD5B4FF),
          avatar: Color(0xFF58358D),
          accent: Color(0xFFE8C7FF),
          glow: Color(0xAA9B4DFF),
        );
      default:
        return const _BoruSeatPalette(
          background: Color(0xFF211B3B),
          occupied: Color(0xFF26344A),
          selected: Color(0xFF203D35),
          locked: Color(0xFF493321),
          border: Color(0xFF493B68),
          selectedBorder: Color(0xFF6EE7B7),
          occupiedBorder: Color(0xFF536B91),
          avatar: Color(0xFF51416E),
          accent: Color(0xFFC4B5FD),
          glow: Color(0x223B2B66),
        );
    }
  }

  Widget _buildSeat(Map<String, dynamic> seat) {
    final seatNumber = seat['seatNumber'] as int;
    final userPublicId = seat['userPublicId']?.toString();
    final localIdentity = voiceService.room?.localParticipant?.identity;

    final isMe = userPublicId != null && userPublicId == localIdentity;
    final isLocked = seat['isLocked'] == true;
    final isOccupied = userPublicId != null;

    final name = seat['name']?.toString().trim().isNotEmpty == true
        ? seat['name'].toString()
        : seat['username']?.toString() ?? 'Kullanıcı';

    final avatarUrl = seat['avatarUrl']?.toString() ?? '';

    bool? micEnabled;

    if (isMe) {
      micEnabled = microphoneEnabled;
    } else if (userPublicId != null) {
      final room = voiceService.room;

      if (room != null) {
        for (final participant in room.remoteParticipants.values) {
          if (participant.identity == userPublicId) {
            micEnabled = participant.isMicrophoneEnabled();
            break;
          }
        }
      }
    }

    final theme = _themeForLevel(roomThemeLevel);

    final Color seatColor = isLocked
        ? theme.locked
        : isMe
        ? theme.selected
        : isOccupied
        ? theme.occupied
        : theme.background;

    return GestureDetector(
      onTap: () => _handleSeatTap(seat),
      onLongPress: () => _toggleSeatLock(seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? theme.selectedBorder
                : isOccupied
                ? theme.occupiedBorder
                : theme.border,
            width: isMe ? 2.5 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.glow,
              blurRadius: roomThemeLevel >= 2 ? 14 : 5,
              spreadRadius: roomThemeLevel >= 2 ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: theme.avatar,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Icon(
                          isLocked
                              ? Icons.lock
                              : isOccupied
                              ? Icons.person
                              : Icons.event_seat,
                          color: Colors.white,
                          size: 27,
                        )
                      : null,
                ),
                if (isOccupied && micEnabled != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B0D20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        micEnabled ? Icons.mic : Icons.mic_off,
                        color: micEnabled ? Colors.greenAccent : Colors.white70,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              isLocked
                  ? 'Kilitli'
                  : isOccupied
                  ? name
                  : 'Boş koltuk',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            if (BoruRoleBadge.hasBadge(
              seat['platformRole']?.toString(),
              seat['roomRole']?.toString(),
            ))
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BoruRoleBadge(
                  platformRole: seat['platformRole']?.toString(),
                  roomRole: seat['roomRole']?.toString(),
                  compact: true,
                ),
              )
            else
              Text(
                isMe ? 'Siz' : 'Koltuk $seatNumber',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socketService.disconnect();
    chatMessages.dispose();
    roomListener?.dispose();
    voiceService.disconnect();
    super.dispose();
  }

  Future<void> _openGiftShop() async {
    final me = widget.currentUserPublicId.trim();

    if (me.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı kimliği bulunamadı. Yeniden giriş yapın.'),
        ),
      );
      return;
    }

    final recipients = <String, String>{};

    for (final seat in seats) {
      final id = seat['userPublicId']?.toString().trim() ?? '';
      if (id.isEmpty || id == me) continue;

      final name = seat['name']?.toString().trim().isNotEmpty == true
          ? seat['name'].toString()
          : seat['username']?.toString() ?? id;

      recipients[id] = name;
    }

    final receiver = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Hediye Alıcısını Seç'),
              subtitle: Text('Hediyeler gerçek coin bakiyenizden düşer.'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Kendime Gönder'),
              subtitle: const Text('Kendi hesabıma hediye'),
              onTap: () => Navigator.pop(sheetContext, me),
            ),
            const Divider(),
            if (recipients.isEmpty)
              const ListTile(
                title: Text('Başka alıcı bulunamadı'),
                subtitle: Text(
                  'Dolu koltuklardaki kullanıcılar burada görünür.',
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: recipients.entries.map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(entry.value),
                    subtitle: Text(entry.key),
                    onTap: () => Navigator.pop(sheetContext, entry.key),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || receiver == null || receiver.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BoruGiftShop(
          apiBaseUrl: BoruConfig.apiBaseUrl,
          accessToken: widget.accessToken,
          roomPublicId: widget.roomPublicId,
          receiverPublicId: receiver,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomPalette = BoruThemeController.instance.roomPalette;
    final room = voiceService.room;

    final participantCount = room == null
        ? 0
        : room.remoteParticipants.length +
              (room.localParticipant == null ? 0 : 1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leaveRoom();
      },
      child: Scaffold(
        backgroundColor: roomPalette.background,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          heroTag: 'boruGiftButton',
          tooltip: 'Hediye Gönder',
          backgroundColor: roomPalette.accent,
          foregroundColor: roomPalette.background,
          onPressed: _openGiftShop,
          child: const Icon(Icons.card_giftcard, size: 28),
        ),
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFD36A),
                size: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      roomPalette.name.toUpperCase(),
                      style: TextStyle(
                        color: roomPalette.accent,
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: roomPalette.surface,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Oda sohbeti',
              icon: const Icon(Icons.forum_outlined),
              onPressed: leaving ? null : _openChat,
            ),
            PopupMenuButton<String>(
              tooltip: 'Oda seçenekleri',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) async {
                if (value == 'theme') {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BoruThemeSettingsPage(),
                    ),
                  );
                  if (mounted) setState(() {});
                } else if (value == 'refresh') {
                  await _refreshSeats();
                } else if (value == 'leave_seat') {
                  await _leaveMySeat();
                } else if (value == 'exit') {
                  await leaveRoom();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'theme', child: Text('Görünüm ve temalar')),
                const PopupMenuItem(value: 'refresh', child: Text('Koltukları yenile')),
                if (seats.any((seat) =>
                    seat['userPublicId'] == widget.currentUserPublicId))
                  const PopupMenuItem(value: 'leave_seat', child: Text('Koltuktan kalk')),
                const PopupMenuItem(value: 'exit', child: Text('Odadan ayrıl')),
              ],
            ),
          ],
        ),
        body: connecting
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: leaving ? null : leaveRoom,
                        child: const Text('Odadan ayrıl'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            roomPalette.accent.withValues(alpha: 0.35),
                            roomPalette.surface,
                            roomPalette.background,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: roomPalette.accent,
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x553F245C),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Color(0xFFFFD36A),
                            size: 38,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            roomPalette.name.toUpperCase(),
                            style: TextStyle(
                              color: roomPalette.accent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.roomName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090611),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF8E6B38),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  color: Colors.greenAccent,
                                  size: 9,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$participantCount KATILIMCI',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 13),
                          const Text(
                            'SESİNLE SAHNEYE ÇIK',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        'MİKROFON SAHNESİ',
                        style: TextStyle(
                          color: Color(0xFFFFD36A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Text(
                      'Boş koltuğa dokunarak sohbete katıl',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    // KOLTUK TEMA ÖNİZLEME
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 7,
                        children: [
                          for (final theme in [
                            (0, 'Standart'),
                            (1, 'Mavi'),
                            (2, 'Bordo'),
                            (3, 'Mor'),
                          ])
                            ChoiceChip(
                              label: Text(theme.$2),
                              selected: roomThemeLevel == theme.$1,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    roomThemeLevel = theme.$1;
                                  });
                                }
                              },
                              selectedColor: const Color(0xFFFFD36A),
                              backgroundColor: const Color(0xFF211B3B),
                              labelStyle: TextStyle(
                                color: roomThemeLevel == theme.$1
                                    ? const Color(0xFF211027)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              side: BorderSide(
                                color: roomThemeLevel == theme.$1
                                    ? const Color(0xFFFFD36A)
                                    : const Color(0xFF493B68),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: seatsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : seats.isEmpty
                          ? const Center(
                              child: Text(
                                'Henüz koltuk bulunmuyor.',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth < 390
                                    ? 3 : constraints.maxWidth < 650 ? 4 : 5;
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8,
                                  ),
                                  itemCount: seats.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 9,
                                    mainAxisSpacing: 11,
                                    mainAxisExtent: 130,
                                  ),
                                  itemBuilder: (context, index) => _buildSeat(seats[index]),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Dolu koltuğa dokun: profil açılır. Kalkmak için üstteki koltuk simgesini kullan.\n'
                        'Yönetici kilitleme için boş koltuğa basılı tutun.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: roomPalette.surface,
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color: roomPalette.accent.withValues(alpha: 0.32),
                          ),
                          boxShadow: const [BoxShadow(
                            color: Color(0x66000000), blurRadius: 20,
                          )],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: leaving ? null : toggleMicrophone,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: microphoneEnabled
                                        ? const Color(0xFFFF8080)
                                        : roomPalette.accent,
                                    foregroundColor: roomPalette.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  icon: Icon(microphoneEnabled
                                      ? Icons.mic_off_rounded : Icons.mic_rounded),
                                  label: Text(microphoneEnabled
                                      ? 'MİKROFONU KAPAT' : 'MİKROFONU AÇ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.4,
                                      )),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filled(
                              tooltip: 'Odadan ayrıl',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFAF4052),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: leaving ? null : leaveRoom,
                              icon: const Icon(Icons.logout_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
