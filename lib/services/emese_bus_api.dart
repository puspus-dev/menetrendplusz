import 'package:dio/dio.dart';

/// Kliens a [puspus-dev/EMESE](https://github.com/puspus-dev/EMESE) busz API-hoz.
///
/// Útvonalminta (a repo `index.ts` szerint):
///   /api/EMESE/{Város}/stops?q=
///   /api/EMESE/{Város}/departures?stop=&limit=
///   /api/EMESE/{Város}/last-departed?stop=
///   /api/EMESE/{Város}/eta?trip=&date=&stop=&delay_sec=
///
/// Példa:
///   https://kosgeuczrikklalmrvcb.supabase.co/api/EMESE/Nyiregyhaza/stops?q=autóbusz
class EmeseBusApi {
  static const String defaultProjectUrl =
      'https://kosgeuczrikklalmrvcb.supabase.co';

  /// Ismert város-szegmensek a GitHub mappanevek szerint.
  static const List<EmeseCity> cities = [
    EmeseCity(id: 'Nyiregyhaza', label: 'Nyíregyháza', path: 'Nyiregyhaza'),
    EmeseCity(id: 'Kisvarda', label: 'Kisvárda', path: 'Kisvarda'),
  ];

  final Dio _dio;

  /// Pl. https://kosgeuczrikklalmrvcb.supabase.co
  final String projectUrl;

  /// Nyiregyhaza | Kisvarda
  final String cityPath;

  EmeseBusApi({
    String? projectUrl,
    String cityPath = 'Nyiregyhaza',
    Dio? dio,
  })  : projectUrl = _normalizeProject(projectUrl ?? defaultProjectUrl),
        cityPath = cityPath,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'MenetrendPlus/0.2',
              },
              validateStatus: (s) => s != null && s < 500,
            ));

  /// Visszafelé kompatibilitás: ha valaki "baseUrl"-t vár.
  static const String defaultBaseUrl =
      '$defaultProjectUrl/api/EMESE/Nyiregyhaza';

  static String _normalizeProject(String raw) {
    var u = raw.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    // Ha valaki teljes path-ot adott, vágjuk a project root-ra.
    final idx = u.indexOf('/api/EMESE');
    if (idx > 0) u = u.substring(0, idx);
    final idx2 = u.indexOf('/functions/v1');
    if (idx2 > 0) u = u.substring(0, idx2);
    return u;
  }

  /// Elsődleges: /api/EMESE/{city}/…
  String get apiBase => '$projectUrl/api/EMESE/$cityPath';

  /// Alternatíva, ha a function a klasszikus Supabase path alatt fut.
  String get functionsBase =>
      '$projectUrl/functions/v1/api/EMESE/$cityPath';

  bool get isConfigured => projectUrl.startsWith('http');

  Uri _uri(String endpoint, [Map<String, String>? query, {bool alt = false}]) {
    final base = alt ? functionsBase : apiBase;
    final e = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$base$e').replace(queryParameters: query);
  }

  Future<Response<dynamic>> _get(
    String endpoint,
    Map<String, String>? query,
  ) async {
    final primary = await _dio.getUri(_uri(endpoint, query));
    // 404 → próbáld a functions/v1 path-ot
    if (primary.statusCode == 404) {
      final alt = await _dio.getUri(_uri(endpoint, query, alt: true));
      return alt;
    }
    return primary;
  }

  Future<bool> ping() async {
    try {
      final res = await _get('', null);
      if (res.statusCode == 200) return true;
      final res2 = await _get('/stops', {'q': 'a'});
      return res2.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<EmeseStop>> findStops(String q) async {
    final res = await _get('/stops', {'q': q});
    _throwIfBad(res);
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => EmeseStop(
              id: '${m['stop_id'] ?? ''}',
              name: '${m['stop_name'] ?? ''}',
            ))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  Future<EmeseDeparturesResult> departures({
    required String stop,
    int limit = 15,
    DateTime? at,
  }) async {
    final q = <String, String>{
      'stop': stop,
      'limit': '$limit',
    };
    if (at != null) q['at'] = at.toUtc().toIso8601String();
    final res = await _get('/departures', q);
    _throwIfBad(res);
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    final list = (data['departures'] as List? ?? [])
        .whereType<Map>()
        .map((m) => EmeseDeparture.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return EmeseDeparturesResult(
      stopName: '${data['stop'] ?? stop}',
      at: data['at']?.toString(),
      source: data['source']?.toString(),
      departures: list,
    );
  }

  Future<Map<String, dynamic>> lastDeparted({
    required String stop,
    DateTime? at,
  }) async {
    final q = <String, String>{'stop': stop};
    if (at != null) q['at'] = at.toUtc().toIso8601String();
    final res = await _get('/last-departed', q);
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {};
  }

  void _throwIfBad(Response res) {
    if (res.statusCode == 404) {
      throw EmeseApiException(
        'EMESE API nem elérhető (404). '
        'Várt path: $apiBase/stops?q=… '
        '(vagy $functionsBase/…). Deployold a function-t.',
        statusCode: 404,
      );
    }
    if (res.statusCode != null && res.statusCode! >= 400) {
      final msg = res.data is Map
          ? (res.data['error'] ?? res.data['message'])?.toString()
          : res.data?.toString();
      throw EmeseApiException(
        msg ?? 'HTTP ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }
  }
}

class EmeseCity {
  final String id;
  final String label;
  final String path;
  const EmeseCity({
    required this.id,
    required this.label,
    required this.path,
  });
}

class EmeseApiException implements Exception {
  final String message;
  final int? statusCode;
  EmeseApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class EmeseStop {
  final String id;
  final String name;
  const EmeseStop({required this.id, required this.name});
}

class EmeseDeparture {
  final String tripId;
  final String? serviceDate;
  final String route;
  final String? headsign;
  final String? scheduledDeparture;
  final String? scheduledDepartureLocal;
  final int? minutesUntil;

  const EmeseDeparture({
    required this.tripId,
    required this.route,
    this.serviceDate,
    this.headsign,
    this.scheduledDeparture,
    this.scheduledDepartureLocal,
    this.minutesUntil,
  });

  factory EmeseDeparture.fromJson(Map<String, dynamic> m) => EmeseDeparture(
        tripId: '${m['trip_id'] ?? ''}',
        serviceDate: m['service_date']?.toString(),
        route: '${m['route'] ?? ''}',
        headsign: m['headsign']?.toString(),
        scheduledDeparture: m['scheduled_departure']?.toString(),
        scheduledDepartureLocal: m['scheduled_departure_local']?.toString(),
        minutesUntil: m['minutes_until'] is int
            ? m['minutes_until'] as int
            : int.tryParse('${m['minutes_until']}'),
      );
}

class EmeseDeparturesResult {
  final String stopName;
  final String? at;
  final String? source;
  final List<EmeseDeparture> departures;

  const EmeseDeparturesResult({
    required this.stopName,
    required this.departures,
    this.at,
    this.source,
  });
}
