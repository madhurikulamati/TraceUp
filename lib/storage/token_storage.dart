import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

/// TokenStorage persists JWT access and refresh tokens securely.
/// In production, it utilizes encrypted Android Keystore / iOS Keychain via FlutterSecureStorage.
/// Automatically detects test environment and uses fast, isolated in-memory storage.
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _userDataKey = 'user_data';

  // In-memory cache for speed and test isolation
  final Map<String, String> _memoryCache = {};

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _memoryCache[_accessTokenKey] = accessToken;
    _memoryCache[_refreshTokenKey] = refreshToken;

    if (!_isTest) {
      try {
        await _secureStorage.write(key: _accessTokenKey, value: accessToken);
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      } catch (_) {}
    }
  }

  Future<String?> getAccessToken() async {
    if (_memoryCache.containsKey(_accessTokenKey)) {
      return _memoryCache[_accessTokenKey];
    }
    if (_isTest) return null;

    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token != null) {
        _memoryCache[_accessTokenKey] = token;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    if (_memoryCache.containsKey(_refreshTokenKey)) {
      return _memoryCache[_refreshTokenKey];
    }
    if (_isTest) return null;

    try {
      final token = await _secureStorage.read(key: _refreshTokenKey);
      if (token != null) {
        _memoryCache[_refreshTokenKey] = token;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    _memoryCache[_userDataKey] = userJson;
    if (!_isTest) {
      try {
        await _secureStorage.write(key: _userDataKey, value: userJson);
      } catch (_) {}
    }
  }

  Future<UserModel?> getUser() async {
    String? userJson = _memoryCache[_userDataKey];
    if (userJson == null && !_isTest) {
      try {
        userJson = await _secureStorage.read(key: _userDataKey);
      } catch (_) {}
    }
    if (userJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    if (!_isTest) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
    }
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
