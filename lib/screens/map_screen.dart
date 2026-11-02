import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/live_vehicle.dart';
import '../services/mav_emma_api.dart';
import '../services/app_state.dart';
import '../services/live_vehicles.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LiveVehiclesService _live = LiveVehiclesService();
  final MapController _mapController = MapController();

  List<LiveVehicle> _vehicles = [];
  bool _loading = false;
  String? _error;
  Timer? _timer;
  bool _showTrains = true;
  bool _showBuses = true;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Térkép középpontjából kérjük a buszokat
      LatLng center;
      try {
        center = _mapController.camera.center;
      } catch (_) {
        center = const LatLng(47.5, 19.05);
      }

      final useEmese = context.read<AppState>().useEmese;
      final all = await _live.fetchAll(
        mapLat: center.latitude,
        mapLon: center.longitude,
        latSpan: 2.0,
        lonSpan: 2.8,
        useEmese: useEmese,
      );

      if (mounted) {
        setState(() {
          _vehicles = all;
          _lastUpdate = DateTime.now();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }


  /// Egyszerű rács-alapú cluster zoom < 10 esetén

  // Szolgáltató outline — vastag, jól elkülönül a késés kitöltéstől
  static const Color _outlineMav = AppTheme.mavOutline;
  static const Color _outlineVolan = AppTheme.volanOutline;

  Color _providerOutline(LiveVehicle v) =>
      v.provider == 'mav' || v.kind == VehicleKind.train
          ? _outlineMav
          : _outlineVolan;

  List<Marker> _buildMarkers(List<LiveVehicle> vehicles, double zoom) {
    if (zoom >= 10 || vehicles.length < 25) {
      return vehicles.map(_vehicleMarker).toList();
    }

    // ~0.15 fokos cellák zoom 7 körül
    final cell = zoom < 8 ? 0.25 : 0.12;
    final buckets = <String, List<LiveVehicle>>{};
    for (final v in vehicles) {
      final key =
          '${(v.lat / cell).floor()}_${(v.lon / cell).floor()}';
      buckets.putIfAbsent(key, () => []).add(v);
    }

    final markers = <Marker>[];
    for (final entry in buckets.entries) {
      final group = entry.value;
      if (group.length == 1) {
        markers.add(_vehicleMarker(group.first));
        continue;
      }
      final lat = group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
      final lon = group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;
      final worst = group.map((e) => e.delayMinutes ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
      Color color;
      if (worst < 10) {
        color = const Color(0xFF2E7D32);
      } else if (worst <= 20) {
        color = const Color(0xFFF9A825);
      } else if (worst <= 30) {
        color = const Color(0xFFEF6C00);
      } else {
        color = const Color(0xFFC62828);
      }

      markers.add(Marker(
        point: LatLng(lat, lon),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () {
            // Zoom a clusterre
            _mapController.move(LatLng(lat, lon), zoom + 2);
          },
          child: Builder(builder: (_) {
            final mavN = group.where((e) => e.provider == 'mav' || e.kind == VehicleKind.train).length;
            final outline = mavN >= group.length / 2 ? _outlineMav : _outlineVolan;
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: outline, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(1.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${group.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ));
    }
    return markers;
  }

  Marker _vehicleMarker(LiveVehicle v) {
    final outline = _providerOutline(v);
    return Marker(
      point: LatLng(v.lat, v.lon),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _onVehicleTap(v),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Külső vastag outline = szolgáltató (MÁV kék / Volán sárga)
            border: Border.all(color: outline, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: v.delayColor,
              shape: BoxShape.circle,
              // Vékony fehér elválasztó a kitöltés és az outline között
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(v.icon, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }


  List<LiveVehicle> get _filtered {
    return _vehicles.where((v) {
      if (v.kind == VehicleKind.train && !_showTrains) return false;
      if (v.kind == VehicleKind.bus && !_showBuses) return false;
      return true;
    }).toList();
  }

  void _onVehicleTap(LiveVehicle v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VehicleDetailSheet(vehicle: v),
    );
  }



  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final trainCount =
        filtered.where((v) => v.kind == VehicleKind.train).length;
    final busCount = filtered.where((v) => v.kind == VehicleKind.bus).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Élő térkép'),
        actions: [
          if (_lastUpdate != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}:${_lastUpdate!.second.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
            tooltip: 'Frissítés',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(47.1625, 19.5033),
              initialZoom: 7.2,
              minZoom: 6,
              maxZoom: 16,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() {});
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'hu.menetrend.plus',
              ),
              MarkerLayer(
                markers: _buildMarkers(
                  filtered,
                  () {
                    try {
                      return _mapController.camera.zoom;
                    } catch (_) {
                      return 7.2;
                    }
                  }(),
                ),
              ),
            ],
          ),

          // Szűrők + számláló
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Vonat ($trainCount)'),
                      selected: _showTrains,
                      onSelected: (v) => setState(() => _showTrains = v),
                      avatar: Icon(Icons.train_rounded,
                          size: 18,
                          color: _showTrains ? AppTheme.mavOutline : null),
                      selectedColor: AppTheme.mavOutline.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Busz ($busCount)'),
                      selected: _showBuses,
                      onSelected: (v) => setState(() => _showBuses = v),
                      avatar: Icon(Icons.directions_bus_rounded,
                          size: 18,
                          color: _showBuses ? AppTheme.volanOutline : null),
                      selectedColor: AppTheme.volanOutline.withValues(alpha: 0.15),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Jelmagyarázat
          Positioned(
            left: 12,
            bottom: 16,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kitöltés = késés', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    _legendDot(const Color(0xFF2E7D32), '< 10 perc'),
                    _legendDot(const Color(0xFFF9A825), '10–20 perc'),
                    _legendDot(const Color(0xFFEF6C00), '20–30 perc'),
                    _legendDot(const Color(0xFFC62828), '> 30 perc'),
                    _legendDot(Colors.blueGrey, 'nincs adat'),
                    const SizedBox(height: 8),
                    const Text('Keret = típus', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    _legendRing(const Color(0xFF1565C0), 'MÁV vonat'),
                    _legendRing(const Color(0xFFF9A825), 'Volán busz'),
                  ],
                ),
              ),
            ),
          ),

          if (_error != null)
            Positioned(
              right: 12,
              bottom: 16,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Hiba a frissítéskor',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _legendRing(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              color: Colors.transparent,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

}


/// Alsó lap: EMESE trip megállólista + késés (MÁV)
class _VehicleDetailSheet extends StatefulWidget {
  final LiveVehicle vehicle;
  const _VehicleDetailSheet({required this.vehicle});

  @override
  State<_VehicleDetailSheet> createState() => _VehicleDetailSheetState();
}

class _VehicleDetailSheetState extends State<_VehicleDetailSheet> {
  final _emma = MavEmmaApi();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _trip;
  int? _delayMin;

  LiveVehicle get v => widget.vehicle;

  @override
  void initState() {
    super.initState();
    final gtfsId = v.extra?['gtfsId'] as String?;
    final fromEmese = v.extra?['source'] == 'emese';
    if (fromEmese && gtfsId != null && gtfsId.isNotEmpty) {
      _loadTrip(gtfsId);
    }
  }

  Future<void> _loadTrip(String gtfsId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trip = await _emma.tripDetails(gtfsId);
      int? delay;
      if (trip != null) {
        final stoptimes = trip['stoptimes'] as List? ?? [];
        // Utolsó ismert késés a listából
        for (final st in stoptimes) {
          if (st is! Map) continue;
          final d = st['arrivalDelay'];
          if (d is num) delay = (d / 60).round();
        }
      }
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _delayMin = delay ?? v.delayMinutes;
        _loading = false;
        if (trip == null) _error = 'Nincs részletes EMESE adat';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'EMESE hiba: $e';
      });
    }
  }

  String _fmtSec(dynamic sec) {
    if (sec is! num) return '—';
    final s = sec.toInt();
    final h = (s ~/ 3600) % 24;
    final m = (s % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Color _delayColor(int? d) {
    if (d == null) return Colors.blueGrey;
    if (d < 10) return const Color(0xFF2E7D32);
    if (d <= 20) return const Color(0xFFF9A825);
    if (d <= 30) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dMin = _delayMin ?? v.delayMinutes;
    final delayColor = _delayColor(dMin);
    final delayLabel = dMin == null
        ? 'Késés: nincs adat'
        : (dMin <= 0 ? 'Időben (0 perc késés)' : 'Késés: $dMin perc');

    final stoptimes = _trip?['stoptimes'] as List? ?? [];
    final headsign = (_trip?['tripHeadsign'] as String?) ?? v.headsign;
    final trainName = _trip?['trainName']?.toString();
    final category = _trip?['trainCategoryName']?.toString();

    String subtitle;
    if (category != null || trainName != null) {
      subtitle = [category, trainName]
          .where((e) => e != null && e.isNotEmpty)
          .join(' · ');
    } else {
      subtitle = v.kind == VehicleKind.train ? 'MÁV vonat' : 'Volán busz';
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: delayColor.withValues(alpha: 0.2),
                    child: Icon(v.icon, color: delayColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(subtitle,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _sheetInfo(Icons.schedule_rounded, delayLabel, delayColor),
              if (headsign != null && headsign.isNotEmpty)
                _sheetInfo(Icons.flag_rounded, headsign),
              if (v.speedKmh != null && v.speedKmh! > 0)
                _sheetInfo(
                    Icons.speed_rounded, '${v.speedKmh!.round()} km/h'),
              if (v.model != null)
                _sheetInfo(Icons.directions_bus_filled_rounded, v.model!),
              _sheetInfo(
                Icons.my_location_rounded,
                '${v.lat.toStringAsFixed(5)}, ${v.lon.toStringAsFixed(5)}',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: theme.colorScheme.error, fontSize: 12)),
              ],
              if (stoptimes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Megállók', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...stoptimes.map((st) {
                  if (st is! Map) return const SizedBox.shrink();
                  final stop = st['stop'] as Map? ?? {};
                  final name = stop['name']?.toString() ?? '?';
                  final sched = _fmtSec(
                      st['scheduledArrival'] ?? st['scheduledDeparture']);
                  final real = _fmtSec(
                      st['realtimeArrival'] ?? st['realtimeDeparture']);
                  final rawDelay = st['arrivalDelay'];
                  int? dm;
                  if (rawDelay is num) dm = (rawDelay / 60).round();
                  final dc = _delayColor(dm);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(sched,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            (real != '—' && real != sched) ? real : '',
                            style: TextStyle(
                              color: dc,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (dm != null)
                          Text(
                            dm <= 0 ? '±0' : '+$dm',
                            style: TextStyle(
                              color: dc,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetInfo(IconData icon, String text, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight:
                    color != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
