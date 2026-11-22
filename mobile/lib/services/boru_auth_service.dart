import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/boru_config.dart';

/// BÖRÜ: JWT yalnızca Android'in güvenli depolama alanında saklanır.
/// Şifre hiçbir zaman cihazda saklanmaz.
class BoruAuthService {
  static const _tokenKey = 'boru_auth_access_token';
  static const _userKey = 'boru_auth_user';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? accessToken;
  Map<String, dynamic>? currentUser;

  // GoogleSignIn 7.x yalnızca bir kez başlatılmalıdır.
  static Future<void>? _googleInitialization;

  Future<Map<String, dynamic>> loginWithGoogle() async {
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (webClientId.isEmpty) {
      throw Exception('Google OAuth Web Client ID henüz tanımlanmadı.');
    }
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
    );
    await _googleInitialization;

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google kimlik anahtarı alınamadı.');
    }

    final response = await http
        .post(
          Uri.parse('${BoruConfig.apiBaseUrl}/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 25));

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw Exception(
        'Sunucudan geçersiz yanıt alındı (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Google ile giriş başarısız.',
      );
    }

    final token = data['accessToken'];
    final user = data['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw Exception('Sunucu geçerli BÖRÜ oturumu döndürmedi.');
    }

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
    accessToken = token;
    currentUser = user;
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${BoruConfig.apiBaseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      throw Exception(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Giriş başarısız.',
      );
    }

    final token = data['accessToken'];
    if (token is! String || token.isEmpty) {
      throw Exception('Sunucu geçerli bir erişim anahtarı döndürmedi.');
    }

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw Exception('Sunucu geçerli kullanıcı bilgisi döndürmedi.');
    }

    // Navigasyondan önce diske yaz: uygulama aniden kapansa da oturum kalsın.
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user));
    accessToken = token;
    currentUser = user;
    return data;
  }

  /// Uygulama açılışında çağrılır. 401/403 durumunda oturum temizlenir.
  /// Geçici ağ/sunucu hatalarında önbellekteki kullanıcıyla oturum korunur.
  Future<bool> restoreSession() async {
    String? token;
    String? cachedUserJson;
    try {
      token = await _storage.read(key: _tokenKey);
      cachedUserJson = await _storage.read(key: _userKey);
    } catch (_) {
      return false;
    }
    if (token == null || token.isEmpty) return false;

    Map<String, dynamic>? cachedUser;
    if (cachedUserJson != null) {
      try {
        final decoded = jsonDecode(cachedUserJson);
        if (decoded is Map<String, dynamic>) cachedUser = decoded;
      } catch (_) {
        // Bozuk kullanıcı önbelleği sunucudan yeniden alınabilir.
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('${BoruConfig.apiBaseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return false;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          accessToken = token;
          currentUser = decoded;
          await _storage.write(key: _userKey, value: jsonEncode(decoded));
          return true;
        }
      }
    } catch (_) {
      // İnternet kesilirse mevcut oturum silinmez.
    }

    if (cachedUser != null) {
      accessToken = token;
      currentUser = cachedUser;
      return true;
    }
    return false;
  }

  /// Kullanıcı isteğiyle oturumu tamamen kapatır.
  Future<void> logout() async {
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // BÖRÜ yerel oturumunu kapatmaya devam et.
      }
    }
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    accessToken = null;
    currentUser = null;
  }
}
