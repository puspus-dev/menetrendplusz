import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gtfs_feed.dart';
import '../models/stop.dart';

/// Több városi GTFS feed letöltése és megállók parse-olása.
class CityGtfsService {
  static const String _prefEnabled = 'city_feeds_enabled';
  static const String _prefMetaPrefix = 'city_feed_meta_';

  final Dio _dio;

  CityGtfsService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 3),
              headers: {
                'User-Agent': 'MenetrendPlus/0.5 (Flutter; city-gtfs)',
                'Accept': 'application/zip,application/octet-stream,*/*',
              },
              followRedirects: true,
              maxRedirects: 5,
              responseType: ResponseType.bytes,
              validateStatus: (s) => s != null && s < 500,
            ));

  Future<Directory> _rootDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/city_gtfs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _feedDir(String feedId) async {
    final root = await _rootDir();
    final dir = Directory('${root.path}/$feedId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Engedélyezett feed ID-k
  Future<Set<String>> enabledFeedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefEnabled) ?? [];
    return list.toSet();
  }

  Future<void> setEnabled(String feedId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_prefEnabled) ?? []).toSet();
    if (enabled) {
      set.add(feedId);
    } else {
      set.remove(feedId);
    }
    await prefs.setStringList(_prefEnabled, set.toList());
  }

  Future<Map<String, dynamic>?> feedMeta(String feedId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefMetaPrefix$feedId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMeta(String feedId, int stopCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefMetaPrefix$feedId',
      jsonEncode({
        'stopCount': stopCount,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<bool> hasCached(String feedId) async {
    final dir = await _feedDir(feedId);
    return File('${dir.path}/stops.txt').exists();
  }

  /// Letölt + kicsomagol. [onProgress] 0.0–1.0
  Future<int> downloadFeed(
    GtfsFeed feed, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Letöltés: ${feed.name}…');
    onProgress?.call(0.05);

    final response = await _dio.get<List<int>>(
      feed.url,
      onReceiveProgress: (r, t) {
        if (t > 0) onProgress?.call(0.05 + 0.7 * (r / t));
      },
    );

    final bytes = response.data;
    if (bytes == null || bytes.length < 100) {
      throw Exception('Üres válasz: ${feed.name}');
    }
    // ZIP magic PK
    if (bytes[0] != 0x50 || bytes[1] != 0x4B) {
      throw Exception(
        'Nem ZIP fájl érkezett (${feed.name}). '
        'A forrás botvédelmet vagy HTML-t adhat vissza.',
      );
    }

    onStatus?.call('Kicsomagolás: ${feed.name}…');
    onProgress?.call(0.8);

    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _feedDir(feed.id);

    // Régi fájlok törlése
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        await e.delete(recursive: true);
      }
    } else {
      await dir.create(recursive: true);
    }

    const keep = {
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
      if (!file.isFile) continue;
      var name = file.name.replaceAll('\\', '/');
      if (name.contains('/')) name = name.split('/').last;
      if (!keep.contains(name.toLowerCase()) && !keep.contains(name)) continue;
      final out = File('${dir.path}/$name');
      await out.writeAsBytes(file.content as List<int>);
    }

    onStatus?.call('Megállók betöltése…');
    onProgress?.call(0.92);

    final stops = await parseStops(feed.id);
    await _saveMeta(feed.id, stops.length);
    await setEnabled(feed.id, true);

    onProgress?.call(1.0);
    onStatus?.call('${feed.name}: ${stops.length} megálló');
    return stops.length;
  }

  Future<void> deleteFeed(String feedId) async {
    final dir = await _feedDir(feedId);
    if (await dir.exists()) await dir.delete(recursive: true);
    await setEnabled(feedId, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefMetaPrefix$feedId');
  }

  Future<List<Stop>> parseStops(String feedId) async {
    final dir = await _feedDir(feedId);
    final file = File('${dir.path}/stops.txt');
    if (!await file.exists()) return [];

    final text = await file.readAsString();
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) return [];

    final header = _parseCsvLine(lines.first);
    final idIdx = header.indexOf('stop_id');
    final nameIdx = header.indexOf('stop_name');
    final latIdx = header.indexOf('stop_lat');
    final lonIdx = header.indexOf('stop_lon');
    final codeIdx = header.indexOf('stop_code');

    final stops = <Stop>[];
    for (var i = 1; i < lines.length; i++) {
      final row = _parseCsvLine(lines[i]);
      if (idIdx < 0 || nameIdx < 0 || row.length <= nameIdx) continue;
      final id = row[idIdx];
      final name = row[nameIdx];
      if (id.isEmpty || name.isEmpty) continue;
      stops.add(Stop(
        id: '${feedId}_$id',
        name: name,
        lat: latIdx >= 0 && latIdx < row.length
            ? double.tryParse(row[latIdx])
            : null,
        lon: lonIdx >= 0 && lonIdx < row.length
            ? double.tryParse(row[lonIdx])
            : null,
        provider: feedId,
        code: codeIdx >= 0 && codeIdx < row.length && row[codeIdx].isNotEmpty
            ? row[codeIdx]
            : id,
      ));
    }
    return stops;
  }

  /// Összes engedélyezett város megállói
  Future<List<Stop>> loadAllEnabledStops() async {
    final enabled = await enabledFeedIds();
    final all = <Stop>[];
    for (final id in enabled) {
      if (await hasCached(id)) {
        all.addAll(await parseStops(id));
      }
    }
    return all;
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
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }
}