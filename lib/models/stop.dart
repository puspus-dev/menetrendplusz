class Stop {
  final String id;
  final String name;
  final double? lat;
  final double? lon;
  final String provider; // 'volan' | 'mav' | 'bkk' | ...
  final String? code;

  const Stop({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
    required this.provider,
    this.code,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      provider: json['provider'] as String? ?? 'volan',
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'provider': provider,
        'code': code,
      };
}