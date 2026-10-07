import '../models/user_model.dart';
import '../storage/token_storage.dart';
import 'api_service.dart';
import '../core/constants/api_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<bool> isLoggedIn() async {
    return await _tokenStorage.hasToken();
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      ApiConstants.loginEndpoint,
      data: {
        'email': email,
        'password': password,
      },
    );

    final accessToken = response['access'] as String? ?? '';
    final refreshToken = response['refresh'] as String? ?? '';
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final userJson = response['user'] as Map<String, dynamic>;
    _currentUser = UserModel.fromJson(userJson);
    return _currentUser!;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      ApiConstants.registerEndpoint,
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    final accessToken = response['access'] as String? ?? '';
    final refreshToken = response['refresh'] as String? ?? '';
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final userJson = response['user'] as Map<String, dynamic>;
    _currentUser = UserModel.fromJson(userJson);
    return _currentUser!;
  }

  Future<void> logout() async {
    await _tokenStorage.clearTokens();
    _currentUser = null;
  }

  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final token = await _tokenStorage.getAccessToken();
    if (token == null) return null;

    final response = await _apiService.get(ApiConstants.meEndpoint);
    _currentUser = UserModel.fromJson(response);
    return _currentUser;
  }
}
