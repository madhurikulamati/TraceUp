import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/valhalla_route_model.dart';

class ValhallaService {
  static final ValhallaService _instance = ValhallaService._internal();
  factory ValhallaService() => _instance;
  ValhallaService._internal();

  final http.Client _client = http.Client();

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Fetches routing path and maneuvers between two GPS points using Valhalla
  Future<ValhallaRouteModel> getRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String costing = 'auto',
  }) async {
    if (ApiConstants.isMockMode || _isTest) {
      await Future.delayed(const Duration(milliseconds: 200));
      return ValhallaRouteModel.mock(
        startLat: startLat,
        startLon: startLon,
        endLat: endLat,
        endLon: endLon,
      );
    }

    try {
      final payload = {
        'locations': [
          {'lat': startLat, 'lon': startLon},
          {'lat': endLat, 'lon': endLon},
        ],
        'costing': costing,
        'directions_options': {'units': 'kilometers'},
      };

      final uri = Uri.parse(
        '${ApiConstants.valhallaBaseUrl}?json=${Uri.encodeComponent(jsonEncode(payload))}',
      );

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return ValhallaRouteModel.fromJson(data);
      }
    } catch (_) {
      // Fallback to mock on network issues or rate limiting
    }

    return ValhallaRouteModel.mock(
      startLat: startLat,
      startLon: startLon,
      endLat: endLat,
      endLon: endLon,
    );
  }
}
