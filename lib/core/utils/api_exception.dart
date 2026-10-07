enum ApiExceptionType {
  noInternet,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  serverError,
  badRequest,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiExceptionType type;

  const ApiException({
    required this.message,
    this.statusCode,
    this.type = ApiExceptionType.unknown,
  });

  factory ApiException.fromStatusCode(int statusCode, [String? serverMessage]) {
    switch (statusCode) {
      case 400:
        return ApiException(
          message: serverMessage ?? 'Invalid request. Please check the provided information.',
          statusCode: statusCode,
          type: ApiExceptionType.badRequest,
        );
      case 401:
        return ApiException(
          message: serverMessage ?? 'Invalid email or password. Please try again.',
          statusCode: statusCode,
          type: ApiExceptionType.unauthorized,
        );
      case 403:
        return ApiException(
          message: serverMessage ?? 'You do not have permission to access this resource.',
          statusCode: statusCode,
          type: ApiExceptionType.forbidden,
        );
      case 404:
        return ApiException(
          message: serverMessage ?? 'The requested resource was not found.',
          statusCode: statusCode,
          type: ApiExceptionType.notFound,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiException(
          message: 'Server error. Please try again later or contact support.',
          statusCode: statusCode,
          type: ApiExceptionType.serverError,
        );
      default:
        return ApiException(
          message: serverMessage ?? 'An unexpected error occurred ($statusCode).',
          statusCode: statusCode,
          type: ApiExceptionType.unknown,
        );
    }
  }

  factory ApiException.noInternet() {
    return const ApiException(
      message: 'No internet connection. Please check your network and try again.',
      type: ApiExceptionType.noInternet,
    );
  }

  factory ApiException.timeout() {
    return const ApiException(
      message: 'Connection timed out. The server took too long to respond.',
      type: ApiExceptionType.timeout,
    );
  }

  factory ApiException.invalidResponse() {
    return const ApiException(
      message: 'Received an invalid response from the server.',
      type: ApiExceptionType.unknown,
    );
  }

  @override
  String toString() => message;
}
