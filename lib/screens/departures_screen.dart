import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stop.dart';
import '../models/departure.dart';
import '../services/app_state.dart';
import '../widgets/departure_tile.dart';
import '../widgets/provider_badge.dart';

class DeparturesScreen extends StatefulWidget {
  final Stop stop;

  const DeparturesScreen({super.key, required this.stop});

  @override
  State<DeparturesScreen> createState() => _DeparturesScreenState();
}

class _DeparturesScreenState extends State<DeparturesScreen> {
  List<Departure> _departures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final state = context.read<AppState>();
    try {
      if (widget.stop.provider == 'mav') {
        _departures = await state.fetchMavDepartures(widget.stop);
      } else {
        _departures = await state.fetchVolanDepartures(widget.stop);
      }
    } catch (e) {
      _error = e.toString();
      _departures = state.getMockDepartures(widget.stop);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isMav = widget.stop.provider == 'mav';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.stop.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Frissítés',
          ),
          IconButton(
            icon: Icon(
              state.isFavorite(widget.stop)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: state.isFavorite(widget.stop) ? Colors.red : null,
            ),
            onPressed: () => state.toggleFavorite(widget.stop),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProviderBadge(provider: widget.stop.provider),
                    const SizedBox(width: 8),
                    Text(
                      isMav ? 'Vasútállomás' : 'Autóbusz-állomás / megálló',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isMav ? 'MÁV API' : 'Volán / UTAS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Következő indulások',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Hiba, mock adatok: $_error',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          Expanded(
            child: _loading && _departures.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _departures.isEmpty
                    ? const Center(child: Text('Nincs közelgő járat'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _departures.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            return DepartureTile(
                                departure: _departures[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}