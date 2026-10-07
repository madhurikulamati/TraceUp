import '../core/constants/api_constants.dart';
import '../core/utils/api_exception.dart';
import '../models/user_model.dart';
import '../storage/token_storage.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  /// Checks whether a valid session token exists
  Future<bool> isLoggedIn() async {
    return await _tokenStorage.hasToken();
  }

  /// Authenticates user and securely stores JWT tokens
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.loginEndpoint,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response is! Map<String, dynamic>) {
        throw ApiException.invalidResponse();
      }

      final accessToken = response['access'] as String?;
      final refreshToken = response['refresh'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        throw ApiException.invalidResponse();
      }

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
      );

      final userJson = response['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        _currentUser = UserModel.fromJson(userJson);
        await _tokenStorage.saveUser(_currentUser!);
      }

      return _currentUser ??
          UserModel(id: 1, name: email.split('@').first, email: email);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Registers a new user and stores authentication tokens
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.registerEndpoint,
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      if (response is! Map<String, dynamic>) {
        throw ApiException.invalidResponse();
      }

      final accessToken = response['access'] as String?;
      final refreshToken = response['refresh'] as String?;

      if (accessToken != null && accessToken.isNotEmpty) {
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken ?? '',
        );
      }

      final userJson = response['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        _currentUser = UserModel.fromJson(userJson);
        await _tokenStorage.saveUser(_currentUser!);
      }

      return _currentUser ?? UserModel(id: 2, name: name, email: email);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Terminates user session and removes all stored tokens securely
  Future<void> logout() async {
    await _tokenStorage.clearAll();
    _currentUser = null;
  }

  /// Retrieves the current authenticated user (from cache, storage, or /auth/me/)
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    // Check secure token
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    // Check locally stored user info first
    final storedUser = await _tokenStorage.getUser();
    if (storedUser != null) {
      _currentUser = storedUser;
      return _currentUser;
    }

    try {
      final response = await _apiService.get(ApiConstants.meEndpoint);
      if (response is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(response);
        await _tokenStorage.saveUser(_currentUser!);
        return _currentUser;
      }
    } catch (_) {
      // In case network fails but token exists
    }

    return null;
  }
}
