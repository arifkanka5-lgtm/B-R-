import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../core/boru_config.dart';
import '../services/boru_auth_service.dart';
import '../services/boru_rooms_service.dart';
import '../theme/boru_theme.dart';
import '../widgets/boru_premium_ui.dart';
import 'boru_auth_pages.dart';
import 'boru_user_profile.dart';
import 'boru_voice_room.dart';

class BoruHomePage extends StatefulWidget {
  const BoruHomePage({super.key, required this.authService});

  final BoruAuthService authService;

  @override
  State<BoruHomePage> createState() => _BoruHomePageState();
}

class _BoruHomePageState extends State<BoruHomePage> {
  final BoruRoomsService roomsService = BoruRoomsService();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> rooms = [];
  Map<String, dynamic>? myProfile;
  bool loading = true;
  bool joiningRoom = false;
  String? error;
  String search = '';
  int selectedTab = 0;
  int selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    loadRooms();
    loadMyProfile();
  }

  Future<void> loadRooms() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await roomsService.getRooms();
      if (!mounted) return;
      setState(() {
        rooms = result
            .whereType<Map>()
            .map((room) => Map<String, dynamic>.from(room))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMyProfile() async {
    final token = widget.authService.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final response = await http
          .get(
            Uri.parse('${BoruConfig.apiBaseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (!mounted || decoded is! Map<String, dynamic>) return;
      setState(() => myProfile = decoded);
    } catch (_) {
      // Ağ kesilirse önbellekteki oturum bilgileri gösterilir.
    }
  }

  Future<void> enterRoom(Map<String, dynamic> room) async {
    if (joiningRoom) return;
    final roomId = room['publicId']?.toString();
    final token = widget.authService.accessToken;
    if (roomId == null || roomId.isEmpty || token == null) {
      _notify('Oturum veya oda bilgisi eksik.');
      return;
    }
    if (room['isPrivate'] == true) {
      _notify('Özel oda şifresi henüz etkin değil.');
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
      if (mounted) _notify('Odaya katılamadın: $e');
    } finally {
      if (mounted) setState(() => joiningRoom = false);
    }
  }

  Future<void> _openMyProfile() async {
    final token = widget.authService.accessToken;
    final id =
        (myProfile?['publicId'] ?? widget.authService.currentUser?['publicId'])
            ?.toString();
    if (token == null || id == null || id.isEmpty) {
      _notify('Profil bilgisi bulunamadı.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BoruUserProfilePage(
          userPublicId: id,
          accessToken: token,
          currentUserPublicId: id,
        ),
      ),
    );
    if (mounted) await loadMyProfile();
  }

  Future<void> _openThemes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BoruThemeSettingsPage()),
    );
    if (mounted) setState(() {});
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
      if (mounted) _notify('Çıkış yapılamadı. Tekrar dene.');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredRooms {
    return rooms.where((room) {
      final name = (room['name'] ?? '').toString().toLowerCase();
      final description = (room['description'] ?? '').toString().toLowerCase();
      final query = search.trim().toLowerCase();
      final matchesSearch = name.contains(query) || description.contains(query);
      final private = room['isPrivate'] == true;
      return matchesSearch &&
          (selectedFilter == 0 ||
              (selectedFilter == 1 && !private) ||
              (selectedFilter == 2 && private));
    }).toList();
  }

  Widget _brandHeader() {
    final accent = BoruPremium.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 18, 9),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: 0.65)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.13),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/branding/boru_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BÖRÜ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3.2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'THE VOICE UNIVERSE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          _headerAction(Icons.palette_outlined, 'Temalar', _openThemes),
          const SizedBox(width: 8),
          _headerAction(Icons.refresh_rounded, 'Odaları yenile', loadRooms),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            width: 41,
            height: 41,
            child: Icon(icon, size: 20, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    final accent = BoruPremium.accent;
    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(BoruPremium.surface, accent, 0.17)!,
            const Color(0xFF141420),
            const Color(0xFF090B12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -58,
            top: -66,
            child: Container(
              width: 245,
              height: 245,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: -28,
            top: -33,
            child: Container(
              width: 182,
              height: 182,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 36,
            child: Opacity(
              opacity: 0.42,
              child: Image.asset(
                'assets/branding/boru_logo.png',
                width: 127,
                height: 127,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 14),
                    const SizedBox(width: 7),
                    Text(
                      'BÖRÜ EXPERIENCE',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'DÜNYANI\nSESİNLE KEŞFET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    height: 1.14,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Sesinle bağ kur. Topluluğunu bul.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const Spacer(),
                BoruPremiumButton(
                  compact: true,
                  label: 'ODALARI KEŞFET',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => setState(() => selectedTab = 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statistics() {
    final publicCount = rooms.where((room) => room['isPrivate'] != true).length;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.meeting_room_outlined,
            loading ? '—' : '${rooms.length}',
            'TOPLAM ODA',
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _statCard(
            Icons.public_rounded,
            loading ? '—' : '$publicCount',
            'AÇIK ODA',
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    final accent = BoruPremium.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoruPremium.panel(radius: 19),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 23),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: BoruPremium.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomCollection(List<Map<String, dynamic>> data) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: BoruPremium.accent),
        ),
      );
    }
    if (error != null) {
      return _statePanel(
        Icons.wifi_off_rounded,
        'Odalar yüklenemedi',
        'Bağlantını kontrol edip yeniden deneyebilirsin.',
        loadRooms,
      );
    }
    if (data.isEmpty) {
      return _statePanel(
        Icons.search_off_rounded,
        'Henüz oda bulunamadı',
        'Farklı bir arama veya filtre deneyebilirsin.',
        () => setState(() {
          selectedFilter = 0;
          search = '';
          searchController.clear();
        }),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 690;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: data
              .map(
                (room) => SizedBox(
                  width: width,
                  height: 192,
                  child: BoruRoomCard(
                    room: room,
                    onTap: joiningRoom ? null : () => enterRoom(room),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _statePanel(
    IconData icon,
    String title,
    String description,
    VoidCallback action,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoruPremium.panel(),
      child: Column(
        children: [
          Icon(icon, size: 35, color: BoruPremium.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BoruPremium.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          BoruPremiumButton(
            label: 'TEKRAR DENE',
            icon: Icons.refresh,
            onPressed: action,
            compact: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _exploreContent() {
    final publicRooms = rooms
        .where((room) => room['isPrivate'] != true)
        .take(4)
        .toList();
    return [
      _hero(),
      const SizedBox(height: 18),
      _statistics(),
      const SizedBox(height: 29),
      BoruSectionHeading(
        title: 'Sohbeti keşfet',
        subtitle: 'Herkese açık sesli odalar',
        trailing: TextButton(
          onPressed: () => setState(() => selectedTab = 1),
          child: Text(
            'Tümünü gör',
            style: TextStyle(color: BoruPremium.accent),
          ),
        ),
      ),
      const SizedBox(height: 15),
      _roomCollection(publicRooms),
      const SizedBox(height: 25),
      Container(
        padding: const EdgeInsets.all(19),
        decoration: BoruPremium.panel(),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, size: 26, color: BoruPremium.accent),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topluluğa hoş geldin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sesli odalara katıl, yeni insanlarla tanış.',
                    style: TextStyle(
                      color: BoruPremium.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _roomsContent() {
    return [
      const BoruSectionHeading(
        title: 'Sesli sohbet odaları',
        subtitle: 'Toplulukları keşfet, sohbetlere katıl',
      ),
      const SizedBox(height: 18),
      Container(
        decoration: BoruPremium.panel(radius: 16),
        child: TextField(
          controller: searchController,
          onChanged: (value) => setState(() => search = value),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Oda adı veya açıklaması ara...',
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: BoruPremium.accent),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(0, 'Tümü', Icons.apps_rounded),
            const SizedBox(width: 8),
            _filterChip(1, 'Herkese açık', Icons.public_rounded),
            const SizedBox(width: 8),
            _filterChip(2, 'Özel odalar', Icons.lock_outline_rounded),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _roomCollection(filteredRooms),
    ];
  }

  Widget _filterChip(int index, String label, IconData icon) {
    final selected = selectedFilter == index;
    final accent = BoruPremium.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => setState(() => selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.055),
          border: Border.all(color: selected ? accent : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: selected ? accent : Colors.white60),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _profileContent() {
    final user =
        myProfile ?? widget.authService.currentUser ?? <String, dynamic>{};
    final name = (user['name']?.toString().trim().isNotEmpty ?? false)
        ? user['name'].toString()
        : (user['username']?.toString() ?? 'BÖRÜ Üyesi');
    final avatar = user['avatarUrl']?.toString() ?? '';
    final publicId = user['publicId']?.toString() ?? '—';
    final role = user['platformRole']?.toString() ?? 'USER';
    final roleName = switch (role) {
      'SUPER_ADMIN' => 'SUPER ADMIN',
      'ADMIN' => 'ADMIN',
      'MODERATOR' => 'MODERATOR',
      _ => 'TOPLULUK ÜYESİ',
    };
    return [
      const BoruSectionHeading(
        title: 'Profilim',
        subtitle: 'BÖRÜ kimliğin ve ayarların',
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoruPremium.panel(highlighted: true, radius: 26),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: BoruPremium.accent, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: BoruPremium.accent.withValues(alpha: 0.14),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 43,
                backgroundColor: BoruPremium.surface,
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 43,
                        color: BoruPremium.accent,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              roleName,
              style: TextStyle(
                color: BoruPremium.accent,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Kullanıcı ID: $publicId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BoruPremium.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),
            BoruPremiumButton(
              label: 'PROFİLİMİ GÖRÜNTÜLE',
              icon: Icons.person_outline_rounded,
              onPressed: _openMyProfile,
            ),
          ],
        ),
      ),
      const SizedBox(height: 19),
      _profileAction(
        Icons.palette_outlined,
        'Görünüm ve temalar',
        'BÖRÜ deneyimini kişiselleştir',
        _openThemes,
      ),
      const SizedBox(height: 10),
      _profileAction(
        Icons.refresh_rounded,
        'Profil bilgilerimi yenile',
        'Hesap bilgilerini sunucudan güncelle',
        loadMyProfile,
      ),
      const SizedBox(height: 10),
      _profileAction(
        Icons.logout_rounded,
        'Güvenli çıkış',
        'Bu cihazdaki oturumu kapat',
        _logout,
        destructive: true,
      ),
    ];
  }

  Widget _profileAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action, {
    bool destructive = false,
  }) {
    return Container(
      decoration: BoruPremium.panel(radius: 18),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
        onTap: action,
        leading: Icon(
          icon,
          color: destructive ? const Color(0xFFFF7777) : BoruPremium.accent,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: BoruPremium.textMuted, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _bottomNavigation() {
    final accent = BoruPremium.accent;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 5, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: BoruPremium.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _navigationItem(0, Icons.explore_rounded, 'Keşfet', accent),
            _navigationItem(1, Icons.graphic_eq_rounded, 'Odalar', accent),
            _navigationItem(2, Icons.person_rounded, 'Profil', accent),
          ],
        ),
      ),
    );
  }

  Widget _navigationItem(int index, IconData icon, String label, Color accent) {
    final active = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: active ? accent : Colors.white54),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? accent : Colors.white54,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedTab) {
      0 => _exploreContent(),
      1 => _roomsContent(),
      _ => _profileContent(),
    };
    return Scaffold(
      backgroundColor: BoruThemeController.instance.appPalette.background,
      body: BoruAmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _brandHeader(),
              Expanded(
                child: RefreshIndicator(
                  color: BoruPremium.accent,
                  onRefresh: selectedTab == 2 ? loadMyProfile : loadRooms,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: content,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomNavigation(),
    );
  }
}
