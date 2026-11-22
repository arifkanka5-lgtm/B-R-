import 'boru_voice_room.dart';
import 'boru_auth_pages.dart';
import '../theme/boru_theme.dart';

import 'package:material_ui/material_ui.dart';

import '../services/boru_rooms_service.dart';
import '../services/boru_auth_service.dart';

class BoruHomePage extends StatefulWidget {
  const BoruHomePage({super.key, required this.authService});

  final BoruAuthService authService;

  @override
  State<BoruHomePage> createState() => _BoruHomePageState();
}

class _BoruHomePageState extends State<BoruHomePage> {
  final roomsService = BoruRoomsService();
  final searchController = TextEditingController();

  List<Map<String, dynamic>> rooms = [];
  bool loading = true;
  String? error;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await roomsService.getRooms();

      if (!mounted) return;

      setState(() {
        rooms = result.whereType<Map<String, dynamic>>().toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool joiningRoom = false;

  Future<void> enterRoom(Map<String, dynamic> room) async {
    if (joiningRoom) return;

    final roomId = room['publicId']?.toString();
    final token = widget.authService.accessToken;

    if (roomId == null || roomId.isEmpty || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum veya oda bilgisi eksik.')),
      );
      return;
    }

    if (room['isPrivate'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Özel oda şifresi sonraki adımda eklenecek.'),
        ),
      );
      return;
    }

    setState(() => joiningRoom = true);

    try {
      final result = await roomsService.joinRoom(
        roomPublicId: roomId,
        accessToken: token,
      );

      if (!mounted) return;

      final name = result['roomName'] ?? room['name'] ?? 'Oda';

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BoruVoiceRoomPage(
            roomPublicId: roomId,
            roomName: name.toString(),
            accessToken: token,
            currentUserPublicId:
                widget.authService.currentUser?['publicId']?.toString() ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Katılım hatası: $e')));
    } finally {
      if (mounted) setState(() => joiningRoom = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesaptan çık'),
        content: const Text('BÖRÜ hesabından çıkış yapmak istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const BoruLoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çıkış işlemi tamamlanamadı. Tekrar dene.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = rooms.where((room) {
      final name = (room['name'] ?? '').toString().toLowerCase();
      return name.contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BÖRÜ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        actions: [
          IconButton(
            tooltip: 'Hesaptan çık',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          IconButton(
            tooltip: 'Temalar',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BoruThemeSettingsPage(),
              ),
            ),
          ),
          IconButton(onPressed: loadRooms, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadRooms,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Dünyanı Sesinle Keşfet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() => search = value);
              },
              decoration: const InputDecoration(
                hintText: 'Sesli oda ara...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SESLi SOHBET ODALARI',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text('Odalar yüklenemedi: $error')
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Gösterilecek oda bulunamadı.')),
              )
            else
              ...filtered.map((room) {
                final name = (room['name'] ?? 'İsimsiz oda').toString();
                final description = (room['description'] ?? '').toString();
                final isPrivate = room['isPrivate'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        isPrivate ? Icons.lock : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      description.isEmpty
                          ? 'BÖRÜ sesli sohbet odası'
                          : description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: joiningRoom ? null : () => enterRoom(room),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
