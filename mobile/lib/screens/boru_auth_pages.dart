import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../core/boru_config.dart';
import '../services/boru_auth_service.dart';
import 'boru_home.dart';

const Color _gold = Color(0xFFEBC46E);
const Color _goldDeep = Color(0xFFB8822F);
const Color _fieldBackground = Color(0xFF17191D);
const Color _textSecondary = Color(0xFFB7B5B1);

class BoruSplashPage extends StatefulWidget {
  const BoruSplashPage({super.key});

  @override
  State<BoruSplashPage> createState() => _BoruSplashPageState();
}

class _BoruSplashPageState extends State<BoruSplashPage> {
  @override
  void initState() {
    super.initState();
    _restoreAndNavigate();
  }

  Future<void> _restoreAndNavigate() async {
    final auth = BoruAuthService();
    // Açılış logosu kısa süre görünür; ardından kaydedilmiş oturum doğrulanır.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final signedIn = await auth.restoreSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            signedIn ? BoruHomePage(authService: auth) : const BoruLoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _BoruBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BoruBrandHeader(logoSize: 190, showTagline: true),
            SizedBox(height: 54),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _gold),
            ),
            SizedBox(height: 14),
            Text(
              'Kurt sürüsü hazırlanıyor...',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class BoruLoginPage extends StatefulWidget {
  const BoruLoginPage({super.key});

  @override
  State<BoruLoginPage> createState() => _BoruLoginPageState();
}

class _BoruLoginPageState extends State<BoruLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = BoruAuthService();
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!_validEmail(email) || password.isEmpty) {
      _notify('Geçerli e-posta adresinizi ve şifrenizi girin.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BoruHomePage(authService: _auth),
        ),
      );
    } catch (e) {
      if (mounted) _notify('Giriş yapılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.loginWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => BoruHomePage(authService: _auth),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) _notify('Google ile giriş yapılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResetNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre sıfırlama'),
        content: const Text(
          'Şifre sıfırlama servisi henüz etkin değil. '
          'Bu özellik sunucu tarafında hazırlandığında e-posta ile '
          'sıfırlama bağlantısı gönderebileceğiz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BoruBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BoruBrandHeader(logoSize: 142, showTagline: true),
                  const SizedBox(height: 26),
                  const Text(
                    'Giriş Yap',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Hesabına giriş yap ve kurt sürüsüne katıl!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 26),
                  _BoruInput(
                    controller: _email,
                    label: 'E-posta adresi',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _BoruInput(
                    controller: _password,
                    label: 'Şifre',
                    icon: Icons.lock_outline,
                    obscure: !_showPassword,
                    trailing: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showResetNotice,
                      child: const Text(
                        'Şifremi unuttum',
                        style: TextStyle(color: _gold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _BoruGoldButton(
                    label: 'GİRİŞ YAP',
                    icon: Icons.login,
                    busy: _busy,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 12),
                  _BoruGoogleButton(busy: _busy, onPressed: _googleLogin),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Hesabın yok mu?',
                        style: TextStyle(color: _textSecondary),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BoruRegisterPage(),
                                ),
                              ),
                        child: const Text(
                          'Kayıt Ol',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'BÖRÜ  •  SESLİ SOHBET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF77736E),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BoruRegisterPage extends StatefulWidget {
  const BoruRegisterPage({super.key});

  @override
  State<BoruRegisterPage> createState() => _BoruRegisterPageState();
}

class _BoruRegisterPageState extends State<BoruRegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _register() async {
    if (_busy) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || name.length > 50) {
      _notify('İsim 1–50 karakter arasında olmalıdır.');
      return;
    }
    if (!_validEmail(email)) {
      _notify('Geçerli bir e-posta adresi girin.');
      return;
    }
    if (password.length < 8 || password.length > 128) {
      _notify('Şifre 8–128 karakter arasında olmalıdır.');
      return;
    }
    if (password != _confirm.text) {
      _notify('Şifreler eşleşmiyor.');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await http
          .post(
            Uri.parse('${BoruConfig.apiBaseUrl}/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_serverMessage(response));
      }
      final auth = BoruAuthService();
      await auth.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => BoruHomePage(authService: auth),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) _notify('Kayıt tamamlanamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final auth = BoruAuthService();
      await auth.loginWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => BoruHomePage(authService: auth),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) _notify('Google ile kayıt yapılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BoruBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: _gold),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const _BoruBrandHeader(logoSize: 104, showTagline: false),
                  const SizedBox(height: 18),
                  const Text(
                    'Kayıt Ol',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'BÖRÜ ailesine katıl, yerini al!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  _BoruInput(
                    controller: _name,
                    label: 'Adınız / görünen isim',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _BoruInput(
                    controller: _email,
                    label: 'E-posta adresi',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _BoruInput(
                    controller: _password,
                    label: 'Şifre (en az 8 karakter)',
                    icon: Icons.lock_outline,
                    obscure: !_showPassword,
                    trailing: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BoruInput(
                    controller: _confirm,
                    label: 'Şifreyi tekrar girin',
                    icon: Icons.verified_user_outlined,
                    obscure: !_showPassword,
                  ),
                  const SizedBox(height: 22),
                  _BoruGoldButton(
                    label: 'KAYIT OL',
                    icon: Icons.person_add_alt_1,
                    busy: _busy,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 12),
                  _BoruGoogleButton(busy: _busy, onPressed: _googleLogin),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Zaten hesabın var mı?',
                        style: TextStyle(color: _textSecondary),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Giriş Yap',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _validEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

String _serverMessage(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is List) return message.join(', ');
      if (message != null) return message.toString();
    }
  } catch (_) {
    // Non-JSON error response.
  }
  return 'Sunucu hatası: ${response.statusCode}';
}

class _BoruBackground extends StatelessWidget {
  const _BoruBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF19160F), Color(0xFF08090B), Color(0xFF060607)],
            stops: [0, 0.42, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -130,
              right: -115,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_gold.withValues(alpha: 0.12), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _BoruBrandHeader extends StatelessWidget {
  const _BoruBrandHeader({required this.logoSize, required this.showTagline});
  final double logoSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _goldDeep, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.16),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/branding/boru_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 16),
          const Text(
            'DÜNYANI SESİNLE KEŞFET',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _BoruInput extends StatelessWidget {
  const _BoruInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _gold),
        suffixIcon: trailing,
        filled: true,
        fillColor: _fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF494035)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _BoruGoldButton extends StatelessWidget {
  const _BoruGoldButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF17130B),
          disabledBackgroundColor: const Color(0xFF655331),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF17130B),
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
      ),
    );
  }
}

class _BoruGoogleButton extends StatelessWidget {
  const _BoruGoogleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: _goldDeep, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Text(
          'G',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: _gold,
          ),
        ),
        label: const Text(
          'Google ile Devam Et',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
