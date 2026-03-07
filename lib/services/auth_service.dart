import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const String _authBaseUrl = 'https://auth.tomenu.sk';
const String _tokenKey    = 'auth_token';

// ── User model ────────────────────────────────────────────────────────────────

class AuthUser {
  final int     id;
  final String  email;
  final String? displayName;
  final String  createdAt;
  final bool    isPremium;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
    required this.isPremium,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id:          j['id'] as int,
    email:       j['email'] as String,
    displayName: j['display_name'] as String?,
    createdAt:   j['created_at'] as String,
    isPremium:   (j['is_premium'] as bool?) ?? false,
  );

  String get displayNameOrEmail => displayName?.isNotEmpty == true ? displayName! : email;
}

// ── Result types ──────────────────────────────────────────────────────────────

class AuthResult {
  final bool      success;
  final AuthUser? user;
  final String?   error;

  const AuthResult.ok(this.user)  : success = true,  error = null;
  const AuthResult.err(this.error): success = false, user  = null;
}

// ── Auth exceptions ───────────────────────────────────────────────────────────

class AuthException implements Exception {
  final int    statusCode;
  final String message;
  AuthException(this.statusCode, this.message);

  @override
  String toString() => message;
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

  AuthUser? get user         => _user;
  bool      get isLoggedIn   => _user != null;
  bool      get initialized  => _initialized;

  // ── Init — call on app startup ────────────────────────────────────────────

  Future<void> init() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        final result = await _me(token);
        _user = result;
      }
    } catch (_) {
      // token invalid or network error — stay logged out
    }
    _initialized = true;
    notifyListeners();
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<AuthResult> register(String email, String password, {String? displayName}) async {
    try {
      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':        email.trim().toLowerCase(),
          'password':     password,
          if (displayName != null && displayName.isNotEmpty)
            'display_name': displayName.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 201) {
        await _storage.write(key: _tokenKey, value: body['token'] as String);
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        return AuthResult.ok(_user);
      }

      return AuthResult.err(_extractError(body, res.statusCode));
    } on AuthException catch (e) {
      return AuthResult.err(e.message);
    } catch (e) {
      return AuthResult.err('Could not connect to server');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<AuthResult> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_authBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email.trim().toLowerCase(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        await _storage.write(key: _tokenKey, value: body['token'] as String);
        _user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        notifyListeners();
        return AuthResult.ok(_user);
      }

      return AuthResult.err(_extractError(body, res.statusCode));
    } catch (e) {
      return AuthResult.err('Could not connect to server');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        await http.post(
          Uri.parse('$_authBaseUrl/auth/logout'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // best effort — always clear locally
    }
    await _storage.delete(key: _tokenKey);
    _user = null;
    notifyListeners();
  }

  // ── Get current token (for future API calls) ──────────────────────────────

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  // ── Private: /auth/me ─────────────────────────────────────────────────────

  Future<AuthUser?> _me(String token) async {
    final res = await http.get(
      Uri.parse('$_authBaseUrl/auth/me'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
    }
    // 401 = token expired/invalid — delete it
    if (res.statusCode == 401) {
      await _storage.delete(key: _tokenKey);
    }
    return null;
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  String _extractError(Map<String, dynamic> body, int statusCode) {
    final msg = body['error'] as String? ?? 'Unknown error';
    return switch (statusCode) {
      409 => 'Email already registered',
      401 => 'Invalid email or password',
      429 => 'Too many attempts — try again later',
      _   => msg,
    };
  }
}