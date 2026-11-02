import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Egyszerű GTFS-RT Alerts olvasó (protobuf → olvasható szövegek).
/// Teljes schema-parser nélkül: kinyeri a UTF-8 string mezőket a FeedMessage-ből.
/// Szeged: http://szegedimenetrend.hu/gtfs.dat
class GtfsRtAlertsService {
  final Dio _dio;

  GtfsRtAlertsService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.bytes,
              headers: {'User-Agent': 'MenetrendPlus/0.2'},
            ));

  /// Visszaadja a feedben talált figyelmeztető szövegeket (header / description).
  Future<List<String>> fetchAlertTexts(String url) async {
    final res = await _dio.get<List<int>>(url);
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return [];
    return extractStrings(Uint8List.fromList(bytes));
  }

  /// Protobuf wire format: length-delimited string mezők (wire type 2).
  static List<String> extractStrings(Uint8List data) {
    final out = <String>[];
    var i = 0;
    while (i < data.length) {
      final key = _readVarint(data, i);
      if (key == null) break;
      i = key.next;
      final wire = key.value & 0x7;
      if (wire == 0) {
        // varint
        final v = _readVarint(data, i);
        if (v == null) break;
        i = v.next;
      } else if (wire == 1) {
        // 64-bit
        i += 8;
      } else if (wire == 5) {
        // 32-bit
        i += 4;
      } else if (wire == 2) {
        final len = _readVarint(data, i);
        if (len == null) break;
        i = len.next;
        final end = i + len.value;
        if (end > data.length) break;
        final chunk = data.sublist(i, end);
        i = end;
        // nested message vagy string — próbáljuk stringként
        final s = _tryDecodeString(chunk);
        if (s != null) {
          final cleaned = s.trim();
          if (cleaned.length >= 8 &&
              cleaned.contains(RegExp(r'[A-Za-záéíóöőúüűÁÉÍÓÖŐÚÜŰ]'))) {
            out.add(cleaned);
          }
        }
      } else {
        break;
      }
    }
    // dedupe, rövidebb URL-szerűeket szűrjük
    final seen = <String>{};
    final filtered = <String>[];
    for (final s in out) {
      if (s.startsWith('http') && s.length < 80) continue;
      if (seen.add(s)) filtered.add(s);
    }
    return filtered;
  }

  static String? _tryDecodeString(List<int> chunk) {
    try {
      final s = utf8.decode(chunk, allowMalformed: false);
      // ha túl sok kontrollkarakter, valószínű nested message
      final controls = s.codeUnits.where((c) => c < 9 || (c > 13 && c < 32)).length;
      if (controls > s.length * 0.15) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  static ({int value, int next})? _readVarint(Uint8List data, int start) {
    var result = 0;
    var shift = 0;
    var i = start;
    while (i < data.length) {
      final b = data[i++];
      result |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) return (value: result, next: i);
      shift += 7;
      if (shift > 35) return null;
    }
    return null;
  }
}
