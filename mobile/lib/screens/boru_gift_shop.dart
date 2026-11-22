import '../services/boru_gift_service.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

class BoruGiftShop extends StatefulWidget {
  const BoruGiftShop({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
    required this.roomPublicId,
    required this.receiverPublicId,
  });

  final String apiBaseUrl;
  final String accessToken;
  final String roomPublicId;
  final String receiverPublicId;

  @override
  State<BoruGiftShop> createState() => _BoruGiftShopState();
}

class _BoruGiftShopState extends State<BoruGiftShop> {
  static const categories = <String, String>{
    'ALL': 'Tümü',
    'ROMANTIC': '❤️ Romantik',
    'FUN': '🎉 Eğlence',
    'ANIMALS': '🐺 Hayvanlar',
    'VEHICLES': '🏎️ Araçlar',
    'ROYAL': '👑 Kraliyet',
    'SVIP': '🐉 SVIP',
  };

  List<Map<String, dynamic>> gifts = [];
  String category = 'ALL';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadGifts();
  }

  Future<void> loadGifts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final base = widget.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
      final response = await http
          .get(
            Uri.parse('$base/gifts'),
            headers: {'Authorization': 'Bearer ${widget.accessToken}'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw const FormatException('Hediye listesi gecersiz.');
      }

      if (!mounted) return;

      setState(() {
        gifts = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Hediyeler yüklenemedi: $e';
        loading = false;
      });
    }
  }

  bool sending = false;

  Future<void> sendSelectedGift(Map<String, dynamic> gift) async {
    if (sending) return;

    final receiver = widget.receiverPublicId.trim();

    if (receiver.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hediye alıcısı henüz seçilmedi.')),
      );
      return;
    }

    final giftCode = gift['code']?.toString() ?? '';
    final giftName = gift['name']?.toString() ?? 'Hediye';
    final price = int.tryParse(gift['priceCoins']?.toString() ?? '') ?? 0;

    if (giftCode.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geçersiz hediye.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hediye Gönder'),
        content: Text(
          '$giftName\n'
          'Alıcı: $receiver\n'
          'Miktar: 1\n'
          'Toplam: ${formatCoins(price)} Coin\n\n'
          'Bu miktar cüzdanından düşülecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => sending = true);

    try {
      final result = await BoruGiftService.sendGift(
        apiBaseUrl: widget.apiBaseUrl,
        accessToken: widget.accessToken,
        roomPublicId: widget.roomPublicId,
        receiverPublicId: receiver,
        giftCode: giftCode,
        quantity: 1,
        requestId: BoruGiftService.createRequestId(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hediye gönderildi! '
            '${result['totalCoins']} Coin harcandı.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gönderim hatası: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String formatCoins(dynamic value) {
    final number = int.tryParse(value.toString()) ?? 0;
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  IconData giftIcon(String category) {
    switch (category) {
      case 'ROMANTIC':
        return Icons.favorite;
      case 'FUN':
        return Icons.celebration;
      case 'ANIMALS':
        return Icons.pets;
      case 'VEHICLES':
        return Icons.directions_car;
      case 'ROYAL':
        return Icons.workspace_premium;
      case 'SVIP':
        return Icons.auto_awesome;
      default:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = category == 'ALL'
        ? gifts
        : gifts.where((g) => g['category'] == category).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17172B),
        foregroundColor: Colors.white,
        title: const Text('BÖRÜ Hediye Mağazası'),
        actions: [
          IconButton(
            onPressed: loading ? null : loadGifts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: categories.entries.map((entry) {
                final selected = category == entry.key;

                return Padding(
                  padding: const EdgeInsets.all(5),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => category = entry.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.88,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final gift = filtered[index];
                      final giftCategory = gift['category']?.toString() ?? '';

                      return Card(
                        color: const Color(0xFF22223B),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: sending ? null : () => sendSelectedGift(gift),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  giftIcon(giftCategory),
                                  color: Colors.amberAccent,
                                  size: 52,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  gift['name']?.toString() ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${formatCoins(gift['priceCoins'])} Coin',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
