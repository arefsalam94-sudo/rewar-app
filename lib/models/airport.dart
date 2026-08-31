class Airport {
  const Airport({
    required this.id,
    required this.iataCode,
    required this.icaoCode,
    required this.name,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String iataCode;
  final String icaoCode;
  final String name;
  final String city;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;

  String get displayName => city.isEmpty ? name : city;

  factory Airport.fromMap(Map<Object?, Object?> map) => Airport(
    id: '${map['id'] ?? ''}',
    iataCode: '${map['iataCode'] ?? ''}',
    icaoCode: '${map['icaoCode'] ?? ''}',
    name: '${map['name'] ?? ''}',
    city: '${map['city'] ?? ''}',
    country: '${map['country'] ?? ''}',
    countryCode: '${map['countryCode'] ?? ''}',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
  );
}
