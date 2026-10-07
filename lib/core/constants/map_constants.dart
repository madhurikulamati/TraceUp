/// Configuration for MapLibre GL Vector Tile Providers and Map Styles.
///
/// Providers & Styles:
/// 1. OpenFreeMap Liberty: Open-source vector tile service powered by OpenMapTiles & OSM,
///    edge-hosted on Cloudflare CDN. Provides full vector layers: detailed streets,
///    road names, highway shields, 2D/3D building footprints, POIs, parks, water,
///    and neighborhood labels. Requires NO API key.
/// 2. OpenFreeMap Bright: High-contrast, vibrant road network with building contours.
/// 3. Carto Voyager: Clean navigation visual style with landmarks and building outlines.
/// 4. Carto Dark Matter: Night navigation theme.
/// 5. MapTiler (Optional): Configurable via `--dart-define=MAPTILER_API_KEY=...` or constant.
class MapConstants {
  /// Optional MapTiler API Key (injected via Dart define or configured here)
  static const String mapTilerApiKey = String.fromEnvironment('MAPTILER_API_KEY', defaultValue: '');

  /// Vector tile styles
  static const String styleLiberty = 'https://tiles.openfreemap.org/styles/liberty';
  static const String styleBright = 'https://tiles.openfreemap.org/styles/bright';
  static const String styleVoyager = 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';
  static const String styleDarkMatter = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

  /// Default production vector tile style URL
  static String get defaultStyleUrl {
    if (mapTilerApiKey.isNotEmpty) {
      return 'https://api.maptiler.com/maps/streets-v2/style.json?key=$mapTilerApiKey';
    }
    return styleLiberty;
  }

  /// Initial map configuration
  static const double defaultZoom = 15.5; // Optimal zoom level showing streets & building footprints
  static const double userFocusZoom = 16.0;
  static const double deviceFocusZoom = 15.5;
  static const double cityOverviewZoom = 12.0;

  /// Default coordinates fallback
  static const double defaultLatitude = 16.2356;
  static const double defaultLongitude = 80.0498;
}

enum MapStyleType {
  liberty,
  bright,
  voyager,
  dark,
}

class MapStyleOption {
  final MapStyleType type;
  final String label;
  final String styleUrl;
  final String description;

  const MapStyleOption({
    required this.type,
    required this.label,
    required this.styleUrl,
    required this.description,
  });

  static const List<MapStyleOption> options = [
    MapStyleOption(
      type: MapStyleType.liberty,
      label: 'Liberty (Detailed)',
      styleUrl: MapConstants.styleLiberty,
      description: 'Detailed streets, buildings, POIs & parks',
    ),
    MapStyleOption(
      type: MapStyleType.bright,
      label: 'Bright (High Contrast)',
      styleUrl: MapConstants.styleBright,
      description: 'Vibrant road network & building outlines',
    ),
    MapStyleOption(
      type: MapStyleType.voyager,
      label: 'Voyager (Navigation)',
      styleUrl: MapConstants.styleVoyager,
      description: 'Clean transit & landmarks',
    ),
    MapStyleOption(
      type: MapStyleType.dark,
      label: 'Dark Mode',
      styleUrl: MapConstants.styleDarkMatter,
      description: 'Sleek night navigation theme',
    ),
  ];
}
