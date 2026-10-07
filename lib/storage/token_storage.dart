/// TokenStorage handles persisting and retrieving JWT tokens.
/// In Phase 1, this provides an in-memory/mock abstraction ready to plug
/// `flutter_secure_storage` in Phase 2 without changing the interface.
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  String? _accessToken;
  String? _refreshToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    return _refreshToken;
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  Future<bool> hasToken() async {
    return _accessToken != null && _accessToken!.isNotEmpty;
  }
}
