enum TrackingMode {
  balanced,
  active,
  batterySaver,
}

extension TrackingModeDetails on TrackingMode {
  String get title {
    switch (this) {
      case TrackingMode.balanced:
        return 'Balanced';
      case TrackingMode.active:
        return 'High Frequency';
      case TrackingMode.batterySaver:
        return 'Battery Saver';
    }
  }

  String get description {
    switch (this) {
      case TrackingMode.balanced:
        return 'Updates every 15 mins (ideal for everyday protection)';
      case TrackingMode.active:
        return 'Updates every 1 min (high accuracy for lost devices)';
      case TrackingMode.batterySaver:
        return 'Updates every 30 mins (minimizes battery consumption)';
    }
  }

  int get defaultIntervalMinutes {
    switch (this) {
      case TrackingMode.balanced:
        return 15;
      case TrackingMode.active:
        return 1;
      case TrackingMode.batterySaver:
        return 30;
    }
  }

  int get distanceFilterMeters {
    switch (this) {
      case TrackingMode.balanced:
        return 100;
      case TrackingMode.active:
        return 10;
      case TrackingMode.batterySaver:
        return 500;
    }
  }
}
