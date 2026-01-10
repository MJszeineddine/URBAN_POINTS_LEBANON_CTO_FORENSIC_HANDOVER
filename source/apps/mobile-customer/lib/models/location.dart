class UserLocation {
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'captured_at': capturedAt.toIso8601String(),
    };
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      capturedAt: DateTime.parse(map['captured_at'] as String),
    );
  }
}
