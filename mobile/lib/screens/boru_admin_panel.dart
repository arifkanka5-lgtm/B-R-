import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import '../core/boru_config.dart';

const _gold = Color(0xFFEBC46E);
const _bg = Color(0xFF08090D);
const _panel = Color(0xFF17191F);

class BoruAdminPanel extends StatefulWidget {
  const BoruAdminPanel({super.key, required this.accessToken});
  final String accessToken;
  @override
  State<BoruAdminPanel> createState() => _BoruAdminPanelState();
}

class _BoruAdminPanelState extends State<BoruAdminPanel> {
  int tab = 0;
  bool busy = true;
  String? error;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> entries = [];
  int offset = 0;
  static const int limit = 30;

  @override
  void initState() { super.initState(); _load(); }

  Future<dynamic> _api(String path, {String method = 'GET', Object? body}) async {
    final uri = Uri.parse('${BoruConfig.apiBaseUrl}$path');
    final headers = <String, String>{'Authorization': 'Bearer ${widget.accessToken}', 'Content-Type': 'application/json'};
    final response = await (method == 'PATCH'
      ? http.patch(uri, headers: headers, body: jsonEncode(body))
      : http.get(uri, headers: headers)).timeout(const Duration(seconds: 20));
    dynamic data;
    try { data = jsonDecode(response.body); } catch (_) { data = null; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? data['message'] : null;
      throw Exception('HTTP ${response.statusCode}: ${message ?? 'İşlem başarısız'}');
    }
    return data;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { busy = true; error = null; });
    try {
      if (tab == 0) {
        final result = await _api('/admin/stats');
        if (result is! Map) throw Exception('Geçersiz istatistik yanıtı');
        if (mounted) setState(() => stats = Map<String, dynamic>.from(result));
      } else {
        final endpoint = switch (tab) { 1 => 'users', 2 => 'rooms', _ => 'audit' };
        final result = await _api('/admin/$endpoint?limit=$limit&offset=$offset');
        if (result is! List) throw Exception('Geçersiz liste yanıtı');
        if (mounted) setState(() => entries = result.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _switch(int index) { setState(() { tab = index; offset = 0; entries = []; }); _load(); }

  Future<void> _changeActive(Map<String, dynamic> entry, bool active) async {
    final id = entry['publicId']?.toString();
    if (id == null || id.isEmpty) return;
    final isUser = tab == 1;
    final label = (entry['name'] ?? entry['username'] ?? id).toString();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(active ? 'Yeniden etkinleştir' : 'Devre dışı bırak'),
      content: Text('$label için bu işlemi onaylıyor musun?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await _api('/admin/${isUser ? 'users' : 'rooms'}/$id/active', method: 'PATCH', body: {'active': active});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem kaydedildi.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { busy = false; error = e.toString(); });
    }
  }

  Widget _metric(String title, Object? value, IconData icon) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withValues(alpha: .25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _gold), const SizedBox(height: 12),
      Text('${value ?? '—'}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );

  Widget _stats() => LayoutBuilder(builder: (ctx, size) {
    final width = (size.maxWidth - 12) / 2;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      SizedBox(width: width, child: _metric('Toplam kullanıcı', stats['users'], Icons.people_outline)),
      SizedBox(width: width, child: _metric('Aktif kullanıcı', stats['activeUsers'], Icons.verified_user_outlined)),
      SizedBox(width: width, child: _metric('Toplam oda', stats['rooms'], Icons.meeting_room_outlined)),
      SizedBox(width: width, child: _metric('Aktif oda', stats['activeRooms'], Icons.mic_none)),
    ]);
  });

  Widget _entry(Map<String, dynamic> entry) {
    if (tab == 3) {
      return Card(color: _panel, child: ListTile(
        title: Text('${entry['action'] ?? 'İşlem'}', style: const TextStyle(color: _gold)),
        subtitle: Text('Hedef: ${entry['targetPublicId'] ?? '—'}\nYapan: ${entry['actorPublicId'] ?? '—'}\n${entry['createdAt'] ?? ''}', style: const TextStyle(color: Colors.white70)),
      ));
    }
    final isActive = entry['isActive'] == true;
    final isSuperAdmin = tab == 1 && entry['platformRole'] == 'SUPER_ADMIN';
    final name = (entry['name'] ?? entry['username'] ?? entry['publicId'] ?? 'Bilinmeyen').toString();
    return Card(color: _panel, child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 5),
        SelectableText('${entry['publicId'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 5),
        Text(isActive ? 'AKTİF' : 'PASİF', style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11)),
        if (tab == 1) Text('Rol: ${entry['platformRole'] ?? 'USER'} • Seviye: ${entry['level'] ?? '—'}', style: const TextStyle(color: _gold, fontSize: 11)),
        if (tab == 2) Text('Oda sahibi: ${entry['ownerPublicId'] ?? '—'}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
          onPressed: busy || isSuperAdmin ? null : () => _changeActive(entry, !isActive),
          icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 16),
          label: Text(isSuperAdmin ? 'KORUNUYOR' : (isActive ? 'KAPAT' : 'AKTİF ET')),
          style: OutlinedButton.styleFrom(foregroundColor: _gold),
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, foregroundColor: _gold, title: const Text('BÖRÜ • SUPER ADMIN'), actions: [IconButton(onPressed: busy ? null : _load, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: Column(children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text('KURT YÖNETİM MERKEZİ', style: TextStyle(color: _gold, letterSpacing: 2, fontWeight: FontWeight.w900))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final (i, label, icon) in [(0, 'Özet', Icons.dashboard_outlined), (1, 'Kullanıcılar', Icons.people_outline), (2, 'Odalar', Icons.meeting_room_outlined), (3, 'Kayıtlar', Icons.history)])
          Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ChoiceChip(label: Text(label), avatar: Icon(icon, size: 17), selected: tab == i, onSelected: (_) => _switch(i))),
      ])),
      Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (busy) const LinearProgressIndicator(color: _gold),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
        if (!busy && error == null && tab == 0) _stats(),
        if (!busy && error == null && tab != 0) ...[
          if (entries.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Kayıt bulunamadı.', style: TextStyle(color: Colors.white70)))),
          for (final entry in entries) _entry(entry),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(onPressed: offset == 0 ? null : () { offset -= limit; _load(); }, child: const Text('Önceki')),
            Text('Sayfa ${offset ~/ limit + 1}', style: const TextStyle(color: _gold)),
            TextButton(onPressed: entries.length < limit ? null : () { offset += limit; _load(); }, child: const Text('Sonraki')),
          ]),
        ],
      ]))),
    ])))),
  );
}
