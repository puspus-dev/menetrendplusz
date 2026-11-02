import 'package:dio/dio.dart';

/// Nem hivatalos MÁV API kliens (reverse engineered).
/// Dokumentáció: https://nzx.hu/mav-api/
/// Szerverek: https://nzx.hu/mav-api/other/servers
/// Figyelem: saját felelősségre – változhat / breakelhet.
class MavApi {
  static const String uaid = '2Juija1mabqr24Blkx1qkXxJ105j';

  /// Production (PR) szerver – élő adatok
  static const String productionUrl =
      'https://vim.mav-start.hu/VIM/PR/20250529/MobileService.svc/rest/';

  /// QA / UAT
  static const String qaUrl =
      'https://vim.mav-start.hu/VIM/QA/UAT/20250529/MobileService.svc/rest/';

  final Dio _dio;
  final String baseUrl;

  MavApi({String? baseUrl, Dio? dio})
      : baseUrl = baseUrl ?? productionUrl,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? productionUrl,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
            ));

  Map<String, dynamic> get _baseBody => {
        'Nyelv': 'HU',
        'UAID': uaid,
      };

  /// Élő vonatok (GPS, késés, sebesség) — POST /GetVonatok
  Future<List<Map<String, dynamic>>> getVonatok() async {
    final response = await _dio.post('GetVonatok', data: _baseBody);
    final data = response.data;
    if (data is Map && data['Vonatok'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['Vonatok'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }

  /// Vonatlista — POST /GetVonatLista
  Future<List<Map<String, dynamic>>> getVonatLista() async {
    final response = await _dio.post('GetVonatLista', data: _baseBody);
    final data = response.data;
    if (data is Map && data['Vonatok'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['Vonatok'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }

  /// Állomás menetrend + szolgáltatások — POST /GetAllomasInfo
  /// [allomasId] pl. "005501362" (Budapest-Keleti)
  Future<Map<String, dynamic>> getAllomasInfo({
    required String allomasId,
    DateTime? datum,
  }) async {
    final d = datum ?? DateTime.now();
    final unix =
        DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;

    final body = {
      ..._baseBody,
      'AllomasID': allomasId,
      'Datum': unix,
    };

    final response = await _dio.post('GetAllomasInfo', data: body);
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Útvonal / utazási ajánlat (A → B) — POST /GetUtazasiAjanlat
  Future<Map<String, dynamic>> getUtazasiAjanlat({
    required String indAllomasId,
    required String celAllomasId,
    DateTime? datum,
    bool indulasiIdo = true,
  }) async {
    final d = datum ?? DateTime.now();
    final unix =
        DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;

    final body = {
      ..._baseBody,
      'CacheNelkul': false,
      'IndAllomasID': indAllomasId,
      'CelAllomasID': celAllomasId,
      'Datum': unix,
      'IndulasiIdo': indulasiIdo,
      'KeresesiFeltetelek': [],
      'Menupont': 'BelfoldiMenetjegy',
      'Szolgaltatasok': ['52'],
      'Utasok': [
        {
          'CsakFelarJel': false,
          'FogyatekkalElo': false,
          'Kedvezmenyek': <String>[],
          'Mennyiseg': 1,
          'UtasTipus': 'HU_107_018-026',
          'l': false,
        }
      ],
      'BerletTipusa': '',
      'FizetesTimeout': 5,
      'NincsBecsultadatIdo': 20,
      'ModalitasKod': [109, 100, 200],
    };

    final response = await _dio.post('GetUtazasiAjanlat', data: body);
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Hírek / MÁVINFORM — POST /GetHirek
  Future<List<Map<String, dynamic>>> getHirek({String? hirId}) async {
    final body = {
      ..._baseBody,
      if (hirId != null) 'HirID': hirId,
    };
    final response = await _dio.post('GetHirek', data: body);
    final data = response.data;
    if (data is Map && data['Hirek'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['Hirek'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }
}