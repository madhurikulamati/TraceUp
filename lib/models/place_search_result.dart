/// Model representing a place, street, or address search result.
class PlaceSearchResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? type;
  final String? city;
  final String? country;

  const PlaceSearchResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type,
    this.city,
    this.country,
  });

  factory PlaceSearchResult.fromPhotonJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

    final double lon = (coordinates[0] as num).toDouble();
    final double lat = (coordinates[1] as num).toDouble();

    final name = properties['name']?.toString() ?? 'Selected Location';
    final street = properties['street']?.toString();
    final city = properties['city']?.toString() ?? properties['county']?.toString() ?? properties['state']?.toString();
    final country = properties['country']?.toString();

    final parts = <String>[
      name,
      if (street != null && street != name) street,
      ?city,
      ?country,
    ];

    return PlaceSearchResult(
      name: name,
      displayName: parts.join(', '),
      latitude: lat,
      longitude: lon,
      type: properties['osm_value']?.toString() ?? properties['type']?.toString(),
      city: city,
      country: country,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'displayName': displayName,
    'latitude': latitude,
    'longitude': longitude,
    'type': type,
    'city': city,
    'country': country,
  };
}
