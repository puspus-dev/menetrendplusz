import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stop.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_chip.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  Stop? _from;
  Stop? _to;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _isDeparture = true;
  String _mode = 'mav'; // útvonaltervező egyelőre MÁV API
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('hu', 'HU'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<Stop?> _pickStop(String title) async {
    final state = context.read<AppState>();
    final mavStops = state.allStops.where((s) => s.provider == 'mav').toList();
    return showModalBottomSheet<Stop>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = mavStops
                .where((s) =>
                    query.isEmpty ||
                    s.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Állomás keresése...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setModal(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          return ListTile(
                            leading: const Icon(Icons.train_rounded,
                                color: AppTheme.mav),
                            title: Text(s.name),
                            onTap: () => Navigator.pop(ctx, s),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _search() async {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Válassz induló és cél állomást'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_from!.code == null || _to!.code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ehhez az állomáshoz nincs MÁV kód'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final state = context.read<AppState>();
      final dt = DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute);
      final data = await state.mavApi.getUtazasiAjanlat(
        indAllomasId: _from!.code!,
        celAllomasId: _to!.code!,
        datum: dt,
        indulasiIdo: _isDeparture,
      );

      final ajanlatok = data['UtazasiAjanlatok'] as List? ?? [];
      setState(() {
        _results = ajanlatok
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
        if (_results.isEmpty) {
          _error = 'Nincs találat erre az időpontra';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Hiba: $e';
      });
    }
  }

  String _fmtUnix(dynamic v) {
    if (v is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Útvonaltervező')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.trip_origin_rounded,
                        color: AppTheme.primary),
                    title: Text(_from?.name ?? 'Honnan'),
                    subtitle: _from == null
                        ? const Text('Érintsd a választáshoz')
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final s = await _pickStop('Induló állomás (MÁV)');
                      if (s != null) setState(() => _from = s);
                    },
                  ),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      IconButton.filledTonal(
                        onPressed: () => setState(() {
                          final t = _from;
                          _from = _to;
                          _to = t;
                        }),
                        icon: const Icon(Icons.swap_vert_rounded),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_rounded,
                        color: AppTheme.accent),
                    title: Text(_to?.name ?? 'Hova'),
                    subtitle: _to == null
                        ? const Text('Érintsd a választáshoz')
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final s = await _pickStop('Célállomás (MÁV)');
                      if (s != null) setState(() => _to = s);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Időpont', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_rounded,
                              size: 18),
                          label: Text(
                            '${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon:
                              const Icon(Icons.access_time_rounded, size: 18),
                          label: Text(
                            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: true,
                          label: Text('Indulás'),
                          icon: Icon(Icons.departure_board_rounded)),
                      ButtonSegment(
                          value: false,
                          label: Text('Érkezés'),
                          icon: Icon(Icons.flight_land_rounded)),
                    ],
                    selected: {_isDeparture},
                    onSelectionChanged: (s) =>
                        setState(() => _isDeparture = s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Mód', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ProviderChip(
                label: 'MÁV (élő API)',
                color: AppTheme.mav,
                selected: _mode == 'mav',
                onTap: () => setState(() => _mode = 'mav'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _search,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_loading ? 'Keresés…' : 'Keresés',
                  style: const TextStyle(fontSize: 16)),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          ..._results.map((r) {
            final ind = _fmtUnix(r['IndDatum']);
            final erk = _fmtUnix(r['ErkDatum']);
            final dur = r['Idotartam']?.toString() ?? '';
            final km = r['Km'];
            final ar = r['Ar'] is Map ? r['Ar']['Osszeg'] : null;
            final reszletek = r['Reszletek'] as List? ?? [];
            String lineInfo = '';
            if (reszletek.isNotEmpty && reszletek.first is Map) {
              final vonat = (reszletek.first as Map)['Vonat'] as Map? ?? {};
              final szam = vonat['Szam']?.toString() ?? '';
              final jel = (vonat['ViszonylatJeloles'] as Map?)?['Jel']?.toString();
              lineInfo = [jel, szam].where((e) => e != null && e.isNotEmpty).join(' ');
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$ind → $erk',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (ar != null)
                          Text('$ar Ft',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (lineInfo.isNotEmpty) lineInfo,
                        if (dur.isNotEmpty) dur,
                        if (km != null) '$km km',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    if ((r['Utirany'] as Map?)?['ErintettAllomasNevek'] is List)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          ((r['Utirany'] as Map)['ErintettAllomasNevek'] as List)
                              .join(' → '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (_results.isEmpty && !_loading && _error == null)
            Card(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.route_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Válassz állomásokat és keress\nMÁV GetUtazasiAjanlat',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}