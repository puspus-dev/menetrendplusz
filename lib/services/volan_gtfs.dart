import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stop.dart';

/// Volánbusz GTFS kezelő.
/// Forrás: https://gtfs.kti.hu/public-gtfs/volanbusz_gtfs.zip (~100 MB)
class VolanGtfs {
  static const String feedUrl =
      'https://gtfs.kti.hu/public-gtfs/volanbusz_gtfs.zip';

  static const String _prefLastUpdate = 'volan_gtfs_last_update';
  static const String _prefStopCount = 'volan_gtfs_stop_count';

  final Dio _dio;

  VolanGtfs({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
            ));

  Future<DateTime?> get lastUpdate async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefLastUpdate);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<int> get cachedStopCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefStopCount) ?? 0;
  }

  Future<Directory> _gtfsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/volan_gtfs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Letölti a zip-et, kicsomagolja, csak a szükséges fájlokat tartja meg.
  Future<void> downloadAndExtract({
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final dir = await _gtfsDir();
    final zipPath = '${dir.path}/volanbusz_gtfs.zip';

    onStatus?.call('Letöltés indítása…');

    await _dio.download(
      feedUrl,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total * 0.7);
        }
      },
    );

    onStatus?.call('Kicsomagolás…');
    onProgress?.call(0.75);

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final keep = {
      'stops.txt',
      'routes.txt',
      'agency.txt',
      'feed_info.txt',
      'trips.txt',
      'stop_times.txt',
      'calendar.txt',
      'calendar_dates.txt',
    };

    for (final file in archive) {
      if (file.isFile && keep.contains(file.name.split('/').last)) {
        final name = file.name.split('/').last;
        final out = File('${dir.path}/$name');
        await out.writeAsBytes(file.content as List<int>);
      }
    }

    try {
      await File(zipPath).delete();
    } catch (_) {}

    onStatus?.call('Megállók feldolgozása…');
    onProgress?.call(0.9);

    final stops = await parseStops();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastUpdate, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_prefStopCount, stops.length);

    onProgress?.call(1.0);
    onStatus?.call('Kész (${stops.length} megálló)');
  }

  Future<List<Stop>> parseStops() async {
    final dir = await _gtfsDir();
    final file = File('${dir.path}/stops.txt');
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines.first);
    final idIdx = header.indexOf('stop_id');
    final nameIdx = header.indexOf('stop_name');
    final latIdx = header.indexOf('stop_lat');
    final lonIdx = header.indexOf('stop_lon');
    final codeIdx = header.indexOf('stop_code');

    if (idIdx < 0 || nameIdx < 0) return [];

    final stops = <Stop>[];
    for (var i = 1; i < lines.length; i++) {
      final row = _parseCsvLine(lines[i]);
      if (row.length <= nameIdx) continue;

      final name = row[nameIdx].trim();
      if (name.isEmpty) continue;

      stops.add(Stop(
        id: 'volan_${row[idIdx]}',
        name: name,
        lat: latIdx >= 0 && row.length > latIdx
            ? double.tryParse(row[latIdx])
            : null,
        lon: lonIdx >= 0 && row.length > lonIdx
            ? double.tryParse(row[lonIdx])
            : null,
        provider: 'volan',
        code: codeIdx >= 0 && row.length > codeIdx ? row[codeIdx] : null,
      ));
    }

    stops.sort((a, b) => a.name.compareTo(b.name));
    return stops;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString());
    return result;
  }


  /// stop_times.txt-ből következő indulások egy megállóra (stream, memóriatakarékos)
  Future<List<Map<String, String>>> departuresForStopId(
    String stopId, {
    int maxResults = 40,
  }) async {
    final dir = await _gtfsDir();
    final file = File('${dir.path}/stop_times.txt');
    if (!await file.exists()) return [];

    final tripsFile = File('${dir.path}/trips.txt');
    final routeByTrip = <String, String>{};
    final headsignByTrip = <String, String>{};
    if (await tripsFile.exists()) {
      final lines = const LineSplitter().convert(await tripsFile.readAsString());
      if (lines.isNotEmpty) {
        final h = _parseCsvLine(lines.first);
        final ti = h.indexOf('trip_id');
        final ri = h.indexOf('route_id');
        final hi = h.indexOf('trip_headsign');
        for (var i = 1; i < lines.length; i++) {
          final row = _parseCsvLine(lines[i]);
          if (ti >= 0 && ti < row.length) {
            if (ri >= 0 && ri < row.length) routeByTrip[row[ti]] = row[ri];
            if (hi >= 0 && hi < row.length) headsignByTrip[row[ti]] = row[hi];
          }
        }
      }
    }

    final routesFile = File('${dir.path}/routes.txt');
    final shortNameByRoute = <String, String>{};
    if (await routesFile.exists()) {
      final lines = const LineSplitter().convert(await routesFile.readAsString());
      if (lines.isNotEmpty) {
        final h = _parseCsvLine(lines.first);
        final ri = h.indexOf('route_id');
        final si = h.indexOf('route_short_name');
        for (var i = 1; i < lines.length; i++) {
          final row = _parseCsvLine(lines[i]);
          if (ri >= 0 && si >= 0 && ri < row.length && si < row.length) {
            shortNameByRoute[row[ri]] = row[si];
          }
        }
      }
    }

    final results = <Map<String, String>>[];
    final stream = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var headerDone = false;
    var stopIdx = -1;
    var tripIdx = -1;
    var depIdx = -1;

    await for (final line in stream) {
      if (!headerDone) {
        final h = _parseCsvLine(line);
        stopIdx = h.indexOf('stop_id');
        tripIdx = h.indexOf('trip_id');
        depIdx = h.indexOf('departure_time');
        headerDone = true;
        continue;
      }
      if (stopIdx < 0 || depIdx < 0) break;
      final row = _parseCsvLine(line);
      if (row.length <= stopIdx || row[stopIdx] != stopId) continue;

      final tripId = tripIdx >= 0 && tripIdx < row.length ? row[tripIdx] : '';
      final routeId = routeByTrip[tripId] ?? '';
      results.add({
        'stop_id': stopId,
        'trip_id': tripId,
        'departure_time': row[depIdx],
        'route_id': routeId,
        'route_short_name': shortNameByRoute[routeId] ?? routeId,
        'headsign': headsignByTrip[tripId] ?? '',
      });
      if (results.length >= maxResults * 20) break; // bőven, majd szűrünk
    }

    // Mai nap idő szerint szűrés
    final now = DateTime.now();
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;
    int parseTime(String t) {
      final p = t.split(':');
      if (p.length < 2) return 0;
      return (int.tryParse(p[0]) ?? 0) * 3600 +
          (int.tryParse(p[1]) ?? 0) * 60 +
          (p.length > 2 ? (int.tryParse(p[2]) ?? 0) : 0);
    }

    results.sort((a, b) =>
        parseTime(a['departure_time']!).compareTo(parseTime(b['departure_time']!)));

    final upcoming = results.where((r) {
      final sec = parseTime(r['departure_time']!);
      return sec >= nowSec - 300; // 5 perc türelmi
    }).take(maxResults).toList();

    return upcoming;
  }


  Future<bool> get hasCachedData async {
    final dir = await _gtfsDir();
    return File('${dir.path}/stops.txt').exists();
  }
}