class ValhallaRouteModel {
  final double distanceKm;
  final int durationSeconds;
  final List<List<double>> polylineCoordinates; // [[lon, lat], [lon, lat], ...]
  final List<String> maneuvers;

  const ValhallaRouteModel({
    required this.distanceKm,
    required this.durationSeconds,
    required this.polylineCoordinates,
    required this.maneuvers,
  });

  String get durationFormatted {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  String get distanceFormatted {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  factory ValhallaRouteModel.fromJson(Map<String, dynamic> json) {
    double dist = 0.0;
    int duration = 0;
    final maneuversList = <String>[];
    final coords = <List<double>>[];

    try {
      final trip = json['trip'] as Map<String, dynamic>?;
      if (trip != null) {
        final summary = trip['summary'] as Map<String, dynamic>?;
        if (summary != null) {
          dist = (summary['length'] as num?)?.toDouble() ?? 0.0;
          duration = (summary['time'] as num?)?.toInt() ?? 0;
        }

        final legs = trip['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final firstLeg = legs.first as Map<String, dynamic>;
          final maneuversJson = firstLeg['maneuvers'] as List?;
          if (maneuversJson != null) {
            for (final m in maneuversJson) {
              if (m is Map<String, dynamic> && m['instruction'] != null) {
                maneuversList.add(m['instruction'] as String);
              }
            }
          }
        }
      }
    } catch (_) {}

    return ValhallaRouteModel(
      distanceKm: dist,
      durationSeconds: duration,
      polylineCoordinates: coords,
      maneuvers: maneuversList,
    );
  }

  factory ValhallaRouteModel.mock({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    return ValhallaRouteModel(
      distanceKm: 4.8,
      durationSeconds: 720,
      polylineCoordinates: [
        [startLon, startLat],
        [(startLon + endLon) / 2 + 0.002, (startLat + endLat) / 2 + 0.001],
        [(startLon + endLon) / 2, (startLat + endLat) / 2],
        [endLon, endLat],
      ],
      maneuvers: [
        'Head northeast towards target location',
        'Turn right onto Main Avenue',
        'Arrive at device location on your left',
      ],
    );
  }
}
