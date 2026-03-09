import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const String _authBaseUrl = 'https://auth.tomenu.sk';
const String _tokenKey    = 'auth_token';

// ── User model ────────────────────────────────────────────────────────────────

class AuthUser {
  final int     id;
  final String  email;
  final String? displayName;
  final String? nickname;
  final String  createdAt;
  final bool    isPremium;
  final bool    emailVerified;
  final bool    totpEnabled;
  final String? displayNameChangedAt;
  final String? nicknameChangedAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.nickname,
    required this.createdAt,
    required this.isPremium,
    required this.emailVerified,
    required this.totpEnabled,
    this.displayNameChangedAt,
    this.nicknameChangedAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id:                   j['id'] as int,
    email:                j['email'] as String,
    displayName:          j['display_name'] as String?,
    nickname:             j['nickname'] as String?,
    createdAt:            j['created_at'] as String,
    isPremium:            (j['is_premium'] as bool?) ?? false,
    emailVerified:        (j['email_verified'] as bool?) ?? false,
    totpEnabled:          (j['totp_enabled'] as bool?) ?? false,
    displayNameChangedAt: j['display_name_changed_at'] as String?,
    nicknameChangedAt:    j['nickname_changed_at'] as String?,
  );

  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    return email.split('@').first;
  }

  String? get handle {
    if (nickname != null && nickname!.isNotEmpty) return '@$nickname';
    return null;
  }

  int? get nicknameCooldownDays {
    if (nicknameChangedAt == null) return null;
    final last      = DateTime.tryParse(nicknameChangedAt!.replaceAll(' ', 'T')) ?? DateTime.now();
    final daysSince = DateTime.now().difference(last).inDays;
    return daysSince >= 7 ? null : 7 - daysSince;
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class AuthResult {
  final bool      success;
  final AuthUser? user;
  final String?   error;
  final bool      requires2FA;

  const AuthResult.ok(this.user)
      : success = true, error = null, requires2FA = false;

  const AuthResult.err(this.error, { this.requires2FA = false })
      : success = false, user = null;
}

class TwoFASetup {
  final String secret;
  final String otpauthUri;
  const TwoFASetup({ required this.secret, required this.otpauthUri });
}

// ── Service ───────────────────────────────────────────────────────────────────

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthUser? _user;
  bool      _initialized = false;

  AuthUser? get user        => _user;
  bool      get isLoggedIn  => _user != null;
  bool      get initialized => _initialized;

  Future<void> init() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) _user = await _me(token);
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<AuthResult> register(String email, String password, {String? displayName}) async {
    try {
      final res = await _post('/auth/register', {
        'email':    email.trim().toLowerCase(),
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName.trim(),
      });
      final body = _decode(res);
      if (res.statusCode == 201) {
        await _storage.write(key: _tokenKey, value: body['token'] as String);
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        await _registerFcmToken();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(body, res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  Future<AuthResult> login(String email, String password, {String? totpCode}) async {
    try {
      final res = await _post('/auth/login', {
        'email':    email.trim().toLowerCase(),
        'password': password,
        if (totpCode != null) 'totp_code': totpCode,
      });
      final body = _decode(res);
      if (res.statusCode == 200 && body['totp_required'] == true)
        return const AuthResult.err('2FA required', requires2FA: true);
      if (res.statusCode == 200) {
        await _storage.write(key: _tokenKey, value: body['token'] as String);
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        await _registerFcmToken();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(body, res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  Future<void> logout() async {
    try {
      await _unregisterFcmToken();
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        await http.post(
          Uri.parse('$_authBaseUrl/auth/logout'),
          headers: _authHeaders(token),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    try { await _googleSignIn.signOut(); } catch (_) {}
    await _storage.delete(key: _tokenKey);
    _user = null;
    notifyListeners();
  }

  // ── Email verification ────────────────────────────────────────────────────

  Future<AuthResult> verifyEmail(String email, String code) async {
    try {
      final res = await _post('/auth/verify-email', {
        'email': email.trim().toLowerCase(),
        'code':  code.trim(),
      });
      if (res.statusCode == 200) {
        await refreshUser();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  Future<AuthResult> resendVerificationEmail() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return const AuthResult.err('Not logged in');
      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/resend-verification'),
        headers: _authHeaders(token),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return AuthResult.ok(_user);
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<AuthResult> forgotPassword(String email) async {
    try {
      final res = await _post('/auth/forgot-password', {
        'email': email.trim().toLowerCase(),
      });
      if (res.statusCode == 200) return const AuthResult.ok(null);
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  Future<AuthResult> resetPassword(String email, String code, String newPassword) async {
    try {
      final res = await _post('/auth/reset-password', {
        'email':        email.trim().toLowerCase(),
        'code':         code.trim(),
        'new_password': newPassword,
      });
      if (res.statusCode == 200) return const AuthResult.ok(null);
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<AuthResult> updateProfile({String? displayName, String? nickname}) async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return const AuthResult.err('Not logged in');
      final res = await http.patch(
        Uri.parse('$_authBaseUrl/auth/me'),
        headers: _authHeaders(token),
        body: jsonEncode({
          if (displayName != null) 'display_name': displayName.trim(),
          if (nickname != null)    'nickname':     nickname.trim(),
        }),
      ).timeout(const Duration(seconds: 10));
      final body = _decode(res);
      if (res.statusCode == 200) {
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(body, res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  // ── 2FA / TOTP ────────────────────────────────────────────────────────────

  Future<TwoFASetup?> setup2FA() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return null;
      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/totp/setup'),
        headers: _authHeaders(token),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final b = _decode(res);
        return TwoFASetup(
          secret:     b['secret']      as String,
          otpauthUri: b['otpauth_url'] as String,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<AuthResult> verify2FA(String code) async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return const AuthResult.err('Not logged in');
      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/totp/confirm'),
        headers: _authHeaders(token),
        body: jsonEncode({ 'code': code.trim() }),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        await refreshUser();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  Future<AuthResult> disable2FA(String code) async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return const AuthResult.err('Not logged in');
      final req = http.Request('DELETE', Uri.parse('$_authBaseUrl/auth/totp'));
      req.headers.addAll(_authHeaders(token));
      req.body = jsonEncode({ 'code': code.trim() });
      final streamed = await req.send().timeout(const Duration(seconds: 10));
      final res      = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        await refreshUser();
        return AuthResult.ok(_user);
      }
      return AuthResult.err(_extractError(_decode(res), res.statusCode));
    } catch (_) { return const AuthResult.err('Could not connect to server'); }
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<AuthUser?> _me(String token) async {
    final res = await http.get(
      Uri.parse('$_authBaseUrl/auth/me'),
      headers: _authHeaders(token),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200)
      return AuthUser.fromJson((_decode(res))['user'] as Map<String, dynamic>);
    if (res.statusCode == 401) await _storage.delete(key: _tokenKey);
    return null;
  }

  Future<void> refreshUser() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) _user = await _me(token);
    notifyListeners();
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) =>
      http.post(
        Uri.parse('$_authBaseUrl$path'),
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

  Map<String, String> _authHeaders(String token) => {
    'Content-Type':  'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response res) =>
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

  String _extractError(Map<String, dynamic> body, int statusCode) {
    final msg = body['error'] as String? ?? 'Unknown error';
    return switch (statusCode) {
      409 => 'Email already registered',
      401 => 'Invalid email or password',
      429 => 'Too many attempts — try again later',
      _   => msg,
    };
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  // ── Google Sign-In ───────────────────────────────────────────────────────────

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'openid'],
    serverClientId: '121301092418-16qup9o4k2o0gk19e0sucm9mu0q3ja6n.apps.googleusercontent.com',
  );

  /// Sign in with Google. If the user is already logged in, this LINKS the
  /// Google account to the existing session instead of creating a new one.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return AuthResult.err('Sign-in cancelled');

      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return AuthResult.err('No ID token from Google');

      final sessionToken = await _storage.read(key: _tokenKey);
      final headers = sessionToken != null
          ? _authHeaders(sessionToken)
          : {'Content-Type': 'application/json'};

      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/oauth/google'),
        headers: headers,
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 15));

      final body = _decode(res);
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Link mode — no new session token, just refresh user
        if (body['linked'] == true) {
          _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
          notifyListeners();
          return AuthResult.ok(null);
        }
        // Login/register mode — save new session
        await _storage.write(key: _tokenKey, value: body['token'] as String);
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        await _registerFcmToken();
        return AuthResult.ok(null);
      }
      return AuthResult.err(body['error'] as String? ?? 'Google sign-in failed');
    } catch (e) {
      return AuthResult.err('Google sign-in error: $e');
    }
  }

  Future<AuthResult> unlinkGoogle() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return AuthResult.err('Not logged in');
    final res = await http.delete(
      Uri.parse('$_authBaseUrl/auth/oauth/unlink'),
      headers: _authHeaders(token),
      body: jsonEncode({'provider': 'google'}),
    ).timeout(const Duration(seconds: 10));
    final body = _decode(res);
    if (res.statusCode == 200) {
      await refreshUser();
      return AuthResult.ok(null);
    }
    return AuthResult.err(body['error'] as String? ?? 'Failed to unlink');
  }

  Future<List<String>> getLinkedProviders() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return [];
    final res = await http.get(
      Uri.parse('$_authBaseUrl/auth/oauth/providers'),
      headers: _authHeaders(token),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final body = _decode(res);
    final providers = body['providers'] as List<dynamic>? ?? [];
    return providers.map((p) => p['provider'] as String).toList();
  }

  // ── FCM Push Notifications ───────────────────────────────────────────────────

  Future<void> _registerFcmToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await http.post(
        Uri.parse('$_authBaseUrl/auth/fcm'),
        headers: _authHeaders(token),
        body: jsonEncode({'token': fcmToken, 'platform': 'android'}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) { /* non-fatal */ }
  }

  Future<void> _unregisterFcmToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      await http.delete(
        Uri.parse('$_authBaseUrl/auth/fcm'),
        headers: _authHeaders(token),
        body: jsonEncode({'token': fcmToken}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) { /* non-fatal */ }
  }
}