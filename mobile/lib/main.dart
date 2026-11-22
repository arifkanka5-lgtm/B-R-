import 'screens/boru_auth_pages.dart';
import 'theme/boru_theme.dart';

import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BoruThemeController.instance.load();
  runApp(const BoruApp());
}

class BoruApp extends StatelessWidget {
  const BoruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BoruThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'BÖRÜ',
        debugShowCheckedModeBanner: false,
        theme: BoruThemeController.instance.materialTheme,
        home: const BoruSplashPage(),
      ),
    );
  }
}
