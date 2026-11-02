import 'package:dio/dio.dart';
import '../models/departure.dart';

/// UTAS / ride.hu OneBusAway-szerű API (Volán + részben országos).
/// Forrás: IkarusSearcherDiscordBot + OBA kompatibilis végpontok.
class UtasApi {
  static const String base =
      'https://utas.hu/api/query/v1/ws/otp/api/where';
  static const String key = 'ride-web';
  static const String version = '4';
  static const String appVersion = '3.18.0-162511-795842-71060206';

  final Dio _dio;

  UtasApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': 'MenetrendPlus/0.3'},
            ));

  Map<String, dynamic> get _common => {
        'key': key,
        'version': version,
        'appVersion': appVersion,
      };

  /// Megállók a térkép körül
  Future<List<Map<String, dynamic>>> stopsForLocation({
    required double lat,
    required double lon,
    double latSpan = 0.05,
    double lonSpan = 0.05,
  }) async {
    try {
      final res = await _dio.get(
        '$base/stops-for-location.json',
        queryParameters: {
          ..._common,
          'lat': lat,
          'lon': lon,
          'latSpan': latSpan,
          'lonSpan': lonSpan,
        },
      );
      final data = res.data;
      if (data is Map && data['data'] is Map) {
        final list = data['data']['list'] as List? ?? [];
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Indulások / érkezések egy megállóra
  Future<List<Departure>> arrivalsAndDeparturesForStop(String stopId) async {
    try {
      final res = await _dio.get(
        '$base/arrivals-and-departures-for-stop.json',
        queryParameters: {
          ..._common,
          'stopId': stopId,
          'minutesBefore': 5,
          'minutesAfter': 90,
        },
      );
      final data = res.data;
      if (data is! Map || data['status'] == 'INVALID_VALUE') return [];
      final entry = data['data']?['entry'] as Map? ?? data['data'] as Map? ?? {};
      final arrivals = entry['arrivalsAndDepartures'] as List? ??
          data['data']?['list'] as List? ??
          [];
      final refs = data['data']?['references'] as Map? ?? {};
      final routes = refs['routes'] as Map? ?? {};
      final trips = refs['trips'] as Map? ?? {};

      final now = DateTime.now();
      final result = <Departure>[];

      for (final a in arrivals) {
        if (a is! Map) continue;
        final routeId = a['routeId']?.toString();
        final tripId = a['tripId']?.toString();
        final route = routeId != null ? routes[routeId] as Map? : null;
        final trip = tripId != null ? trips[tripId] as Map? : null;

        final line = route?['shortName']?.toString() ??
            a['routeShortName']?.toString() ??
            '?';
        final dest = a['tripHeadsign']?.toString() ??
            trip?['tripHeadsign']?.toString() ??
            '';

        final predicted = a['predictedDepartureTime'] ?? a['predictedArrivalTime'];
        final scheduled = a['scheduledDepartureTime'] ?? a['scheduledArrivalTime'];

        DateTime schedTime = now;
        DateTime? realTime;
        int? delay;

        if (scheduled is num && scheduled > 0) {
          schedTime = DateTime.fromMillisecondsSinceEpoch(scheduled.toInt());
        }
        if (predicted is num && predicted > 0) {
          realTime = DateTime.fromMillisecondsSinceEpoch(predicted.toInt());
          delay = realTime.difference(schedTime).inMinutes;
        } else if (a['scheduleDeviation'] is num) {
          delay = ((a['scheduleDeviation'] as num) / 60).round();
          realTime = schedTime.add(Duration(minutes: delay));
        }

        result.add(Departure(
          id: '${tripId ?? line}_${schedTime.millisecondsSinceEpoch}',
          line: line,
          destination: dest,
          scheduledTime: schedTime,
          realtimeTime: realTime,
          delayMinutes: delay,
          provider: 'volan',
          vehicleType: 'bus',
        ));
      }

      result.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return result;
    } catch (_) {
      return [];
    }
  }
}