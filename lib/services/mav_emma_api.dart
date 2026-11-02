import 'package:dio/dio.dart';
import '../models/live_vehicle.dart';

/// MÁV Emma (OTP2) GraphQL API — élő vonatpozíciók.
/// Forrás: https://github.com/doomhyena/MAVTracker
/// Endpoint: https://emma.mav.hu/otp2-backend/otp/routers/default/index/graphql
class MavEmmaApi {
  static const String endpoint =
      'https://emma.mav.hu/otp2-backend/otp/routers/default/index/graphql';

  final Dio _dio;

  MavEmmaApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
                'Origin': 'https://emma.mav.hu',
                'Referer': 'https://emma.mav.hu/',
                'Accept': 'application/json',
              },
            ));

  /// Élő vonatok egy bounding boxban (default: egész Magyarország)
  Future<List<LiveVehicle>> vehiclePositions({
    double swLat = 45.5,
    double swLon = 16.1,
    double neLat = 48.7,
    double neLon = 22.8,
  }) async {
    const query = r'''
query Vehicles($swLat: Float!, $swLon: Float!, $neLat: Float!, $neLon: Float!) {
  vehiclePositions(
    swLat: $swLat
    swLon: $swLon
    neLat: $neLat
    neLon: $neLon
    modes: [RAIL, RAIL_REPLACEMENT_BUS]
  ) {
    vehicleId
    lat
    lon
    label
    speed
    heading
    lastUpdated
    trip {
      gtfsId
      tripShortName
      tripHeadsign
    }
    prevOrCurrentStop {
      arrivalDelay
      departureDelay
    }
  }
}
''';

    try {
      final res = await _dio.post(
        endpoint,
        data: {
          'query': query,
          'variables': {
            'swLat': swLat,
            'swLon': swLon,
            'neLat': neLat,
            'neLon': neLon,
          },
        },
      );

      final data = res.data;
      if (data is! Map) return [];
      if (data['errors'] != null) {
        // fallback: egyszerű query változók nélkül
        return await _vehiclePositionsSimple(
          swLat: swLat,
          swLon: swLon,
          neLat: neLat,
          neLon: neLon,
        );
      }

      final positions = data['data']?['vehiclePositions'] as List? ?? [];
      return _mapPositions(positions);
    } catch (_) {
      try {
        return await _vehiclePositionsSimple(
          swLat: swLat,
          swLon: swLon,
          neLat: neLat,
          neLon: neLon,
        );
      } catch (_) {
        return [];
      }
    }
  }

  /// MAVTracker-stílusú egyszerű string query
  Future<List<LiveVehicle>> _vehiclePositionsSimple({
    required double swLat,
    required double swLon,
    required double neLat,
    required double neLon,
  }) async {
    final q =
        '{ vehiclePositions(swLat: $swLat, swLon: $swLon, neLat: $neLat, neLon: $neLon, modes: [RAIL, RAIL_REPLACEMENT_BUS]) { vehicleId lat lon label speed heading lastUpdated trip { gtfsId tripShortName tripHeadsign } prevOrCurrentStop { arrivalDelay departureDelay } } }';

    final res = await _dio.post(endpoint, data: {'query': q});
    final data = res.data;
    if (data is! Map) return [];
    final positions = data['data']?['vehiclePositions'] as List? ?? [];
    return _mapPositions(positions);
  }

  List<LiveVehicle> _mapPositions(List positions) {
    final list = <LiveVehicle>[];
    for (final v in positions) {
      if (v is! Map) continue;
      final lat = _toDouble(v['lat']);
      final lon = _toDouble(v['lon']);
      if (lat == null || lon == null) continue;

      final trip = v['trip'] as Map? ?? {};
      final shortName = trip['tripShortName']?.toString() ??
          v['label']?.toString() ??
          '?';
      final headsign = trip['tripHeadsign']?.toString();
      // mav-stat: speed often m/s
      var speed = _toDouble(v['speed']);
      if (speed != null && speed > 0 && speed < 90) {
        // ha túl kicsi ahhoz hogy km/h legyen, m/s → km/h
        speed = speed * 3.6;
      }

      int? delayMin;
      final prev = v['prevOrCurrentStop'] as Map?;
      if (prev != null) {
        final d = prev['departureDelay'] ?? prev['arrivalDelay'];
        if (d is num) delayMin = (d / 60).round();
      }

      list.add(LiveVehicle(
        id: v['vehicleId']?.toString() ??
            trip['gtfsId']?.toString() ??
            shortName,
        label: shortName,
        headsign: headsign,
        lat: lat,
        lon: lon,
        delayMinutes: delayMin,
        speedKmh: speed,
        kind: VehicleKind.train,
        provider: 'mav',
        extra: {
          'gtfsId': trip['gtfsId']?.toString(),
          'heading': _toDouble(v['heading']),
          'source': 'emese',
        },
      ));
    }
    return list;
  }

  /// Egy járat késései / stoptime-ok (opcionális részletek)
  Future<Map<String, dynamic>?> tripDetails(String gtfsId) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final q =
        '{ trip(id: "$gtfsId", serviceDay: "$date") { tripHeadsign trainCategoryName trainName route { longName shortName } stoptimes { stop { name lat lon } realtimeArrival realtimeDeparture arrivalDelay scheduledArrival scheduledDeparture } } }';

    try {
      final res = await _dio.post(endpoint, data: {'query': q});
      final data = res.data;
      if (data is! Map) return null;
      final trip = data['data']?['trip'];
      if (trip is Map) return Map<String, dynamic>.from(trip);
    } catch (_) {}
    return null;
  }

  /// Pozíciók + első elérhető késés a trip stoptimes-ból (lassabb, de pontosabb)
  Future<List<LiveVehicle>> vehiclePositionsWithDelay({
    double swLat = 45.5,
    double swLon = 16.1,
    double neLat = 48.7,
    double neLon = 22.8,
    int maxDetailFetches = 40,
  }) async {
    final base = await vehiclePositions(
      swLat: swLat,
      swLon: swLon,
      neLat: neLat,
      neLon: neLon,
    );

    // Párhuzamosan néhány trip részlet
    final enriched = <LiveVehicle>[];
    var fetches = 0;
    for (final v in base) {
      if (fetches >= maxDetailFetches) {
        enriched.add(v);
        continue;
      }
      final gtfsId = v.extra?['gtfsId'] as String?;
      if (gtfsId == null) {
        enriched.add(v);
        continue;
      }
      fetches++;
      try {
        final trip = await tripDetails(gtfsId);
        int? delayMin;
        if (trip != null) {
          final stoptimes = trip['stoptimes'] as List? ?? [];
          for (final st in stoptimes) {
            if (st is! Map) continue;
            final d = st['arrivalDelay'];
            if (d is num) {
              delayMin = (d / 60).round();
              break;
            }
          }
        }
        enriched.add(LiveVehicle(
          id: v.id,
          label: v.label,
          headsign: (trip?['tripHeadsign'] as String?) ?? v.headsign,
          lat: v.lat,
          lon: v.lon,
          delayMinutes: delayMin ?? v.delayMinutes,
          speedKmh: v.speedKmh,
          kind: v.kind,
          provider: v.provider,
          extra: v.extra,
        ));
      } catch (_) {
        enriched.add(v);
      }
    }
    return enriched;
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}