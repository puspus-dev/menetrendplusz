import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stop.dart';
import '../models/departure.dart';
import 'mav_api.dart';
import 'volan_gtfs.dart';
import 'live_vehicles.dart';
import 'utas_api.dart';
import 'city_gtfs.dart';
import '../models/gtfs_feed.dart';

class AppState extends ChangeNotifier {
  int _currentTab = 0;
  String _searchQuery = '';
  Stop? _selectedStop;
  final List<Stop> _favorites = [];
  List<Stop> _volanStops = [];
  List<Stop> _cityStops = [];
  List<Stop> _mavStops = [];
  Set<String> _enabledCityFeeds = {};
  Map<String, Map<String, dynamic>> _cityFeedMeta = {};
  bool _isLoading = false;
  String? _error;
  String? _statusMessage;
  double _downloadProgress = 0;
  bool _useEmese = false;

  final MavApi mavApi = MavApi();
  final VolanGtfs volanGtfs = VolanGtfs();
  final LiveVehiclesService liveVehicles = LiveVehiclesService();
  final UtasApi utasApi = UtasApi();
  final CityGtfsService cityGtfs = CityGtfsService();

  static const List<Stop> _builtinMavStops = [
    Stop(id: 'mav_005501362', name: 'Budapest-Keleti', provider: 'mav', lat: 47.5004, lon: 19.0839, code: '005501362'),
    Stop(id: 'mav_005501024', name: 'Budapest-Kelenföld', provider: 'mav', lat: 47.4646, lon: 19.0215, code: '005501024'),
    Stop(id: 'mav_005501016', name: 'Budapest-Nyugati', provider: 'mav', lat: 47.5108, lon: 19.0572, code: '005501016'),
    Stop(id: 'mav_005501550', name: 'Budapest-Déli', provider: 'mav', lat: 47.4994, lon: 19.0247, code: '005501550'),
    Stop(id: 'mav_005504507', name: 'Szeged', provider: 'mav', lat: 46.2530, lon: 20.1482, code: '005504507'),
    Stop(id: 'mav_005505501', name: 'Debrecen', provider: 'mav', lat: 47.5300, lon: 21.6250, code: '005505501'),
    Stop(id: 'mav_005512215', name: 'Győr', provider: 'mav', lat: 47.6835, lon: 17.6350, code: '005512215'),
    Stop(id: 'mav_005513301', name: 'Pécs', provider: 'mav', lat: 46.0660, lon: 18.2330, code: '005513301'),
    Stop(id: 'mav_005514201', name: 'Miskolc', provider: 'mav', lat: 48.1030, lon: 20.7910, code: '005514201'),
    Stop(id: 'mav_005511301', name: 'Székesfehérvár', provider: 'mav', lat: 47.1890, lon: 18.4220, code: '005511301'),
    Stop(id: 'mav_005506502', name: 'Szolnok', provider: 'mav', lat: 47.1790, lon: 20.1760, code: '005506502'),
    Stop(id: 'mav_005510173', name: 'Kőbánya-Kispest', provider: 'mav', lat: 47.4630, lon: 19.1490, code: '005510173'),
  ];

  int get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  Stop? get selectedStop => _selectedStop;
  List<Stop> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  double get downloadProgress => _downloadProgress;
  bool get useEmese => _useEmese;
  int get volanStopCount => _volanStops.length;

  Set<String> get enabledCityFeeds => Set.unmodifiable(_enabledCityFeeds);
  Map<String, Map<String, dynamic>> get cityFeedMeta =>
      Map.unmodifiable(_cityFeedMeta);
  int get cityStopCount => _cityStops.length;

  List<Stop> get allStops {
    final list = <Stop>[..._mavStops, ..._volanStops, ..._cityStops];
    if (list.isEmpty) return _builtinMavStops;
    return list;
  }

  List<Stop> get filteredStops {
    final base = allStops;
    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  AppState() {
    _mavStops = List.from(_builtinMavStops);
    _loadPrefs();
    _loadCachedVolan();
    _loadCityFeeds();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useEmese = prefs.getBool('use_emese') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setUseEmese(bool value) async {
    _useEmese = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_emese', value);
    } catch (_) {}
  }

  Future<void> _loadCachedVolan() async {
    try {
      if (await volanGtfs.hasCachedData) {
        _volanStops = await volanGtfs.parseStops();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Volán cache load error: $e');
    }
  }

  Future<void> _loadCityFeeds() async {
    try {
      _enabledCityFeeds = await cityGtfs.enabledFeedIds();
      for (final id in _enabledCityFeeds) {
        final meta = await cityGtfs.feedMeta(id);
        if (meta != null) _cityFeedMeta[id] = meta;
      }
      _cityStops = await cityGtfs.loadAllEnabledStops();
      notifyListeners();
    } catch (e) {
      debugPrint('City feeds load error: $e');
    }
  }

  Future<void> downloadCityFeed(
    GtfsFeed feed, {
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final count = await cityGtfs.downloadFeed(
      feed,
      onProgress: onProgress,
      onStatus: onStatus,
    );
    _enabledCityFeeds = await cityGtfs.enabledFeedIds();
    final meta = await cityGtfs.feedMeta(feed.id);
    if (meta != null) _cityFeedMeta[feed.id] = meta;
    // Frissítjük csak az adott feed megállóit a listában
    _cityStops.removeWhere((s) => s.provider == feed.id);
    _cityStops.addAll(await cityGtfs.parseStops(feed.id));
    notifyListeners();
    debugPrint('City feed ${feed.id}: $count stops');
  }

  Future<void> deleteCityFeed(String feedId) async {
    await cityGtfs.deleteFeed(feedId);
    _enabledCityFeeds.remove(feedId);
    _cityFeedMeta.remove(feedId);
    _cityStops.removeWhere((s) => s.provider == feedId);
    notifyListeners();
  }

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectStop(Stop stop) {
    _selectedStop = stop;
    notifyListeners();
  }

  void clearSelectedStop() {
    _selectedStop = null;
    notifyListeners();
  }

  void toggleFavorite(Stop stop) {
    final exists = _favorites.any((f) => f.id == stop.id);
    if (exists) {
      _favorites.removeWhere((f) => f.id == stop.id);
    } else {
      _favorites.add(stop);
    }
    notifyListeners();
  }

  bool isFavorite(Stop stop) => _favorites.any((f) => f.id == stop.id);

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  /// Volán GTFS frissítés a hivatalos KTI forrásból
  Future<void> refreshVolanGtfs() async {
    _isLoading = true;
    _error = null;
    _statusMessage = 'Volán GTFS letöltése…';
    _downloadProgress = 0;
    notifyListeners();

    try {
      await volanGtfs.downloadAndExtract(
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
        onStatus: (s) {
          _statusMessage = s;
          notifyListeners();
        },
      );
      _volanStops = await volanGtfs.parseStops();
      _statusMessage = 'Volán: ${_volanStops.length} megálló betöltve';
    } catch (e) {
      _error = 'Volán GTFS hiba: $e';
      _statusMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// MÁV állomás indulások (GetAllomasInfo)
  Future<List<Departure>> fetchMavDepartures(Stop stop) async {
    final code = stop.code;
    if (code == null || code.isEmpty) {
      return getMockDepartures(stop);
    }

    try {
      final data = await mavApi.getAllomasInfo(allomasId: code);
      final menetrend = data['Menetrend'] as List? ?? [];
      final now = DateTime.now();
      final result = <Departure>[];

      for (final item in menetrend) {
        if (item is! Map) continue;
        final vonat = item['Vonat'] as Map? ?? {};
        final ido = item['Ido'] as Map? ?? {};

        final szam = vonat['Szam']?.toString() ?? '?';
        final nev = vonat['Nev']?.toString();
        final viszonylat = vonat['Viszonylat'] as Map? ?? {};
        final celKod = viszonylat['CelAllomasKod']?.toString() ?? '';

        String destination = celKod;
        final match = _mavStops.where((s) => s.code == celKod);
        if (match.isNotEmpty) destination = match.first.name;

        final indMenetrendi = ido['IndMenetrendi']?.toString();
        final indMDatum = ido['IndMDatum'];
        final indTenyDatum = ido['IndTenyDatum'];

        DateTime scheduled = now;
        if (indMDatum is num) {
          scheduled = DateTime.fromMillisecondsSinceEpoch(
              indMDatum.toInt() * 1000);
        } else if (indMenetrendi != null) {
          final parts = indMenetrendi.split(':');
          if (parts.length >= 2) {
            scheduled = DateTime(
              now.year,
              now.month,
              now.day,
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0,
            );
          }
        }

        DateTime? realtime;
        int? delay;
        if (indTenyDatum is num) {
          realtime = DateTime.fromMillisecondsSinceEpoch(
              indTenyDatum.toInt() * 1000);
          delay = realtime.difference(scheduled).inMinutes;
        }

        final platform = vonat['IndVagany']?.toString();

        result.add(Departure(
          id: vonat['ID']?.toString() ?? szam,
          line: nev != null && nev.isNotEmpty ? '$szam $nev' : szam,
          destination: destination,
          scheduledTime: scheduled,
          realtimeTime: realtime,
          delayMinutes: delay,
          platform: platform,
          provider: 'mav',
          vehicleType: 'train',
        ));
      }

      result.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return result
          .where((d) =>
              d.scheduledTime.isAfter(now.subtract(const Duration(minutes: 5))))
          .take(30)
          .toList();
    } catch (e) {
      debugPrint('MÁV GetAllomasInfo error: $e');
      return getMockDepartures(stop);
    }
  }


  /// Volán indulások: először UTAS élő API, fallback GTFS stop_times
  Future<List<Departure>> fetchVolanDepartures(Stop stop) async {
    // 1) Próbáljuk UTAS-t többféle stopId formátummal
    final candidates = <String>[];
    if (stop.code != null && stop.code!.isNotEmpty) candidates.add(stop.code!);
    final rawId = stop.id.replaceFirst('volan_', '');
    candidates.add(rawId);
    candidates.add('VOLAN_$rawId');
    candidates.add(stop.id);

    for (final sid in candidates.toSet()) {
      final list = await utasApi.arrivalsAndDeparturesForStop(sid);
      if (list.isNotEmpty) return list;
    }

    // 2) GTFS stop_times offline
    try {
      final rows = await volanGtfs.departuresForStopId(rawId);
      final now = DateTime.now();
      return rows.map((r) {
        final parts = (r['departure_time'] ?? '00:00:00').split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final s = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
        // GTFS megengedi 24+ órát
        final dayOffset = h >= 24 ? 1 : 0;
        final scheduled = DateTime(now.year, now.month, now.day + dayOffset, h % 24, m, s);
        return Departure(
          id: '${r['trip_id']}_${r['departure_time']}',
          line: r['route_short_name'] ?? '?',
          destination: r['headsign'] ?? '',
          scheduledTime: scheduled,
          provider: 'volan',
          vehicleType: 'bus',
        );
      }).toList();
    } catch (e) {
      debugPrint('Volán GTFS departures error: $e');
      return getMockDepartures(stop);
    }
  }

  List<Departure> getMockDepartures(Stop stop) {
    final now = DateTime.now();
    if (stop.provider == 'mav') {
      return [
        Departure(
          id: 'd1',
          line: 'IC 612',
          destination: 'Budapest-Keleti',
          scheduledTime: now.add(const Duration(minutes: 8)),
          realtimeTime: now.add(const Duration(minutes: 12)),
          delayMinutes: 4,
          platform: '3',
          provider: 'mav',
          vehicleType: 'train',
        ),
        Departure(
          id: 'd2',
          line: 'Személy 5401',
          destination: 'Szeged',
          scheduledTime: now.add(const Duration(minutes: 22)),
          delayMinutes: 0,
          platform: '1',
          provider: 'mav',
          vehicleType: 'train',
        ),
      ];
    }
    return [
      Departure(
        id: 'd5',
        line: '1077',
        destination: 'Szeged',
        scheduledTime: now.add(const Duration(minutes: 5)),
        delayMinutes: 0,
        provider: 'volan',
        vehicleType: 'bus',
      ),
      Departure(
        id: 'd6',
        line: '1090',
        destination: 'Debrecen',
        scheduledTime: now.add(const Duration(minutes: 18)),
        realtimeTime: now.add(const Duration(minutes: 25)),
        delayMinutes: 7,
        provider: 'volan',
        vehicleType: 'bus',
      ),
    ];
  }
}