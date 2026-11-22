import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoruPalette {
  const BoruPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.background,
    required this.surface,
    required this.accent,
    required this.secondary,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color background;
  final Color surface;
  final Color accent;
  final Color secondary;
}

class BoruThemes {
  static const all = <BoruPalette>[
    BoruPalette(
      id: 'royal', name: 'Kurt Krallığı', description: 'Siyah ve altın • VIP',
      icon: Icons.workspace_premium,
      background: Color(0xFF090B10), surface: Color(0xFF1B1A1A),
      accent: Color(0xFFE8B954), secondary: Color(0xFF8A6830),
    ),
    BoruPalette(
      id: 'night', name: 'Kurt Gecesi', description: 'Lacivert ve gümüş',
      icon: Icons.nightlight_round,
      background: Color(0xFF081323), surface: Color(0xFF13273E),
      accent: Color(0xFF9CCAF3), secondary: Color(0xFF506E95),
    ),
    BoruPalette(
      id: 'neon', name: 'Neon Arena', description: 'Mor ve neon',
      icon: Icons.bolt,
      background: Color(0xFF130B24), surface: Color(0xFF2A1746),
      accent: Color(0xFFBF82FF), secondary: Color(0xFF7348C8),
    ),
    BoruPalette(
      id: 'svip', name: 'SVIP Kraliyet', description: 'Bordo ve altın',
      icon: Icons.diamond_outlined,
      background: Color(0xFF210D18), surface: Color(0xFF401727),
      accent: Color(0xFFF2C572), secondary: Color(0xFFAA3F62),
    ),
  ];
}

class BoruThemeController extends ChangeNotifier {
  BoruThemeController._();
  static final instance = BoruThemeController._();

  static const _appKey = 'boru_v13_app_theme';
  static const _roomKey = 'boru_v13_room_theme';

  int _appIndex = 2; // Existing purple appearance is closest to Neon Arena.
  int _roomIndex = 0;

  int get appIndex => _appIndex;
  int get roomIndex => _roomIndex;
  BoruPalette get appPalette => BoruThemes.all[_appIndex];
  BoruPalette get roomPalette => BoruThemes.all[_roomIndex];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final app = prefs.getInt(_appKey);
      final room = prefs.getInt(_roomKey);
      if (app != null && app >= 0 && app < BoruThemes.all.length) {
        _appIndex = app;
      }
      if (room != null && room >= 0 && room < BoruThemes.all.length) {
        _roomIndex = room;
      }
    } catch (e) {
      debugPrint('BÖRÜ tema tercihleri okunamadı: $e');
    }
    notifyListeners();
  }

  Future<void> setAppTheme(int index) async {
    if (index < 0 || index >= BoruThemes.all.length) return;
    _appIndex = index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_appKey, index);
    } catch (e) {
      debugPrint('BÖRÜ uygulama teması kaydedilemedi: $e');
    }
  }

  Future<void> setRoomTheme(int index) async {
    if (index < 0 || index >= BoruThemes.all.length) return;
    _roomIndex = index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_roomKey, index);
    } catch (e) {
      debugPrint('BÖRÜ oda teması kaydedilemedi: $e');
    }
  }

  ThemeData get materialTheme {
    final palette = appPalette;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: palette.surface,
      primary: palette.accent,
      secondary: palette.secondary,
      onPrimary: Colors.black87,
      onSurface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      cardColor: palette.surface,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.17)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}

class BoruThemeSettingsPage extends StatelessWidget {
  const BoruThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BoruThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('BÖRÜ • TEMALAR')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('UYGULAMA TEMASI', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.5,
            )),
            const SizedBox(height: 6),
            const Text('Ana ekran, giriş ve uygulama renkleri'),
            const SizedBox(height: 12),
            ...List.generate(BoruThemes.all.length, (index) =>
              _themeTile(context, index, false, controller),
            ),
            const SizedBox(height: 22),
            const Text('SESLİ ODA TEMASI', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.5,
            )),
            const SizedBox(height: 6),
            const Text('Oda arka planı, başlık ve vurgu renkleri'),
            const SizedBox(height: 12),
            ...List.generate(BoruThemes.all.length, (index) =>
              _themeTile(context, index, true, controller),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tema tercihleri bu telefonda saklanır. Oda temasının tüm '
              'katılımcılara aynı görünmesi için sunucu eşitlemesi ayrıca eklenecek.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(BuildContext context, int index, bool room,
      BoruThemeController controller) {
    final palette = BoruThemes.all[index];
    final selected = (room ? controller.roomIndex : controller.appIndex) == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? palette.accent : Colors.white12,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (room) {
            controller.setRoomTheme(index);
          } else {
            controller.setAppTheme(index);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.secondary, palette.background],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(palette.icon, color: palette.accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(palette.name, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15,
                  )),
                  const SizedBox(height: 4),
                  Text(palette.description, style: const TextStyle(
                    color: Colors.white70, fontSize: 12,
                  )),
                ],
              )),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? palette.accent : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
