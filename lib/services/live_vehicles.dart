import 'package:dio/dio.dart';
import '../models/live_vehicle.dart';
import 'mav_api.dart';
import 'mav_emma_api.dart';

/// Élő járművek: MÁV GetVonatok + UTAS (utas.hu) Volán buszok
class LiveVehiclesService {
  final MavApi mavApi;
  final MavEmmaApi emmaApi;
  final Dio _dio;

  LiveVehiclesService({MavApi? mavApi, MavEmmaApi? emmaApi, Dio? dio})
      : mavApi = mavApi ?? MavApi(),
        emmaApi = emmaApi ?? MavEmmaApi(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': 'MenetrendPlus/0.2'},
            ));

  /// MÁV élő vonatok.
  /// [useEmese] true → EMESE GraphQL (belső forrás); false → csak REST GetVonatok.
  Future<List<LiveVehicle>> fetchMavTrains({bool useEmese = false}) async {
    if (useEmese) {
      try {
        final list = await emmaApi.vehiclePositions();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    try {
      final raw = await mavApi.getVonatok();
      final list = <LiveVehicle>[];
      for (final v in raw) {
        final lat = _toDouble(v['GpsLat'] ?? v['EGpsLat']);
        final lon = _toDouble(v['GpsLon'] ?? v['EGpsLon']);
        if (lat == null || lon == null) continue;
        if (lat == 0 && lon == 0) continue;

        final keses = v['Keses'];
        int? delay;
        if (keses is num) delay = keses.round();

        final vonatszam = v['Vonatszam']?.toString() ?? '?';
        final tipus = v['Tipus']?.toString();

        list.add(LiveVehicle(
          id: v['VonatID']?.toString() ?? vonatszam,
          label: vonatszam,
          headsign: tipus,
          lat: lat,
          lon: lon,
          delayMinutes: delay,
          speedKmh: _toDouble(v['Sebesseg']),
          kind: VehicleKind.train,
          provider: 'mav',
        ));
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Volán / UTAS élő buszok egy téglalapon
  /// Forrás: https://utas.hu/api/.../vehicles-for-location.json
  /// (IkarusSearcherDiscordBot alapján)
  Future<List<LiveVehicle>> fetchVolanBuses({
    double lat = 47.5,
    double lon = 19.05,
    double latSpan = 1.5,
    double lonSpan = 2.0,
  }) async {
    try {
      final url =
          'https://utas.hu/api/query/v1/ws/otp/api/where/vehicles-for-location.json'
          '?lat=$lat&latSpan=$latSpan&lon=$lon&lonSpan=$lonSpan'
          '&key=ride-web&version=4&appVersion=3.18.0-162511-795842-71060206';

      final response = await _dio.get(url);
      final data = response.data;
      if (data is! Map) return [];

      final dataObj = data['data'];
      if (dataObj is! Map) return [];

      final vehicles = dataObj['list'] as List? ?? [];
      final refs = dataObj['references'] as Map? ?? {};
      final trips = refs['trips'] as Map? ?? {};
      final routes = refs['routes'] as Map? ?? {};

      final list = <LiveVehicle>[];
      for (final v in vehicles) {
        if (v is! Map) continue;
        final vLat = _toDouble(v['lat'] ?? v['latitude']);
        final vLon = _toDouble(v['lon'] ?? v['longitude']);
        if (vLat == null || vLon == null) continue;

        final tripId = v['tripId']?.toString();
        final routeId = v['routeId']?.toString();
        final trip = tripId != null ? trips[tripId] as Map? : null;
        final route = routeId != null ? routes[routeId] as Map? : null;

        final shortName = route?['shortName']?.toString() ??
            trip?['tripShortName']?.toString() ??
            v['licensePlate']?.toString() ??
            '?';
        final headsign = trip?['tripHeadsign']?.toString() ??
            route?['description']?.toString();

        // status / delay mezők ha vannak
        int? delay;
        final status = v['status'] as Map?;
        if (status != null) {
          final d = status['delay'] ?? status['scheduleDeviation'];
          if (d is num) delay = (d / 60).round(); // sec → perc
        }
        if (delay == null && v['delay'] is num) {
          delay = (v['delay'] as num).round();
        }

        list.add(LiveVehicle(
          id: v['vehicleId']?.toString() ??
              v['licensePlate']?.toString() ??
              '$vLat,$vLon',
          label: shortName,
          headsign: headsign,
          lat: vLat,
          lon: vLon,
          delayMinutes: delay,
          speedKmh: _toDouble(v['speed']),
          kind: VehicleKind.bus,
          provider: 'volan',
          model: v['model']?.toString() ?? v['vehicleType']?.toString(),
        ));
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Összes élő jármű (vonat + busz)
  Future<List<LiveVehicle>> fetchAll({
    double mapLat = 47.5,
    double mapLon = 19.05,
    double latSpan = 1.8,
    double lonSpan = 2.5,
    bool useEmese = false,
  }) async {
    final results = await Future.wait([
      fetchMavTrains(useEmese: useEmese),
      fetchVolanBuses(
        lat: mapLat,
        lon: mapLon,
        latSpan: latSpan,
        lonSpan: lonSpan,
      ),
    ]);
    return [...results[0], ...results[1]];
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}