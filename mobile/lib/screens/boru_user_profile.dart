import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../core/boru_config.dart';
import '../theme/boru_theme.dart';
import '../widgets/boru_premium_ui.dart';
import '../widgets/boru_role_badge.dart';
import 'boru_gift_shop.dart';

class BoruUserProfilePage extends StatefulWidget {
  const BoruUserProfilePage({
    super.key,
    required this.userPublicId,
    required this.accessToken,
    this.roomPublicId,
    this.currentUserPublicId,
  });

  final String userPublicId;
  final String accessToken;
  final String? roomPublicId;
  final String? currentUserPublicId;

  @override
  State<BoruUserProfilePage> createState() => _BoruUserProfilePageState();
}

class _BoruUserProfilePageState extends State<BoruUserProfilePage> {
  late Future<Map<String, dynamic>> _profile;

  bool get _isMe => widget.userPublicId == widget.currentUserPublicId;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final uri =
        Uri.parse(
          '${BoruConfig.apiBaseUrl}/auth/users/${Uri.encodeComponent(widget.userPublicId)}',
        ).replace(
          queryParameters: widget.roomPublicId == null
              ? null
              : {'roomPublicId': widget.roomPublicId!},
        );
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer ${widget.accessToken}'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Profil bilgileri alınamadı (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz profil yanıtı.');
    }
    return decoded;
  }

  void _refresh() {
    if (mounted) setState(() => _profile = _loadProfile());
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final name = TextEditingController(text: profile['name']?.toString() ?? '');
    final username = TextEditingController(
      text: profile['username']?.toString() ?? '',
    );
    final bio = TextEditingController(text: profile['bio']?.toString() ?? '');
    final avatar = TextEditingController(
      text: profile['avatarUrl']?.toString() ?? '',
    );
    final key = GlobalKey<FormState>();
    bool saving = false;
    String? error;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161925),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PROFİLİ DÜZENLE',
                    style: TextStyle(
                      color: BoruPremium.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 17),
                  TextFormField(
                    controller: name,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: 'Görünen ad'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Görünen ad gerekli.' : null,
                  ),
                  TextFormField(
                    controller: username,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı',
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(text)
                          ? null
                          : '3–20 karakter, harf/rakam/alt çizgi.';
                    },
                  ),
                  TextFormField(
                    controller: bio,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Hakkımda'),
                  ),
                  TextFormField(
                    controller: avatar,
                    decoration: const InputDecoration(
                      labelText: 'Profil fotoğrafı (HTTPS URL)',
                    ),
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      return uri != null &&
                              uri.scheme == 'https' &&
                              uri.hasAuthority
                          ? null
                          : 'Geçerli bir HTTPS adresi girin.';
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  BoruPremiumButton(
                    label: saving ? 'KAYDEDİLİYOR...' : 'DEĞİŞİKLİKLERİ KAYDET',
                    icon: Icons.check_circle_outline,
                    onPressed: saving
                        ? null
                        : () async {
                            if (key.currentState?.validate() != true) return;
                            setSheetState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              final data = <String, dynamic>{
                                'name': name.text.trim(),
                                'bio': bio.text.trim(),
                                if (username.text.trim().isNotEmpty)
                                  'username': username.text.trim(),
                                if (avatar.text.trim().isNotEmpty)
                                  'avatarUrl': avatar.text.trim(),
                              };
                              final response = await http
                                  .patch(
                                    Uri.parse(
                                      '${BoruConfig.apiBaseUrl}/auth/me',
                                    ),
                                    headers: {
                                      'Authorization':
                                          'Bearer ${widget.accessToken}',
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode(data),
                                  )
                                  .timeout(const Duration(seconds: 15));
                              if (response.statusCode < 200 ||
                                  response.statusCode >= 300) {
                                String detail = 'Güncelleme başarısız.';
                                try {
                                  final decoded = jsonDecode(response.body);
                                  if (decoded is Map &&
                                      decoded['message'] != null) {
                                    detail = decoded['message'].toString();
                                  }
                                } catch (_) {}
                                throw Exception(detail);
                              }
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            } catch (e) {
                              if (sheetContext.mounted) {
                                setSheetState(() => error = e.toString());
                              }
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    name.dispose();
    username.dispose();
    bio.dispose();
    avatar.dispose();
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accent = BoruPremium.accent;
    return Scaffold(
      backgroundColor: BoruThemeController.instance.appPalette.background,
      appBar: AppBar(
        title: const Text(
          'KULLANICI PROFİLİ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Profili yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BoruAmbientBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: accent));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Profil yüklenemedi.',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              );
            }
            final profile = snapshot.data!;
            final avatarUrl = profile['avatarUrl']?.toString() ?? '';
            final username = profile['username']?.toString() ?? '';
            final name =
                (profile['name']?.toString().trim().isNotEmpty ?? false)
                ? profile['name'].toString()
                : (username.isEmpty ? 'BÖRÜ Üyesi' : username);
            final bio = profile['bio']?.toString() ?? '';
            final canGift = widget.roomPublicId?.isNotEmpty == true && !_isMe;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 31, 18, 28),
                  decoration: BoruPremium.panel(radius: 27, highlighted: true),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.20),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 53,
                          backgroundColor: BoruPremium.surface,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 54,
                                  color: accent,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: BoruPremium.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      BoruRoleBadge(
                        platformRole: profile['platformRole']?.toString(),
                        roomRole: profile['roomRole']?.toString(),
                      ),
                      const SizedBox(height: 19),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'ID: ${profile['publicId']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'SEVİYE ${profile['level'] ?? 1}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          fontSize: 12,
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 9),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.6,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_isMe) ...[
                        const SizedBox(height: 23),
                        BoruPremiumButton(
                          label: 'PROFİLİ DÜZENLE',
                          icon: Icons.edit_outlined,
                          onPressed: () => _editProfile(profile),
                        ),
                      ],
                      if (canGift) ...[
                        const SizedBox(height: 23),
                        BoruPremiumButton(
                          label: 'HEDİYE GÖNDER',
                          icon: Icons.card_giftcard_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BoruGiftShop(
                                apiBaseUrl: BoruConfig.apiBaseUrl,
                                accessToken: widget.accessToken,
                                roomPublicId: widget.roomPublicId!,
                                receiverPublicId: widget.userPublicId,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
