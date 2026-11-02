import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/stop_tile.dart';
import '../widgets/provider_chip.dart';
import 'departures_screen.dart';
import 'feeds_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    var stops = state.filteredStops;
    if (_filter == 'volan') {
      stops = stops.where((s) => s.provider == 'volan').toList();
    } else if (_filter == 'mav') {
      stops = stops.where((s) => s.provider == 'mav').toList();
    } else if (_filter == 'city') {
      stops = stops
          .where((s) => s.provider != 'volan' && s.provider != 'mav')
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menetrend+'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city_rounded),
            tooltip: 'Városi menetrendek',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedsScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Beállítások',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'emese') {
                final s = context.read<AppState>();
                await s.setUseEmese(!s.useEmese);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.useEmese
                            ? 'EMESE Rendszer bekapcsolva'
                            : 'EMESE Rendszer kikapcsolva',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else if (value == 'cities') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedsScreen()),
                );
              }
            },
            itemBuilder: (ctx) {
              final enabled = context.read<AppState>().useEmese;
              return [
                CheckedPopupMenuItem<String>(
                  value: 'emese',
                  checked: enabled,
                  child: const Text('EMESE Rendszer'),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded),
            tooltip: 'Volán GTFS frissítés',
            onPressed: state.isLoading
                ? null
                : () async {
                    await state.refreshVolanGtfs();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.error ??
                                state.statusMessage ??
                                'Frissítve',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAbout(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.isLoading) ...[
            LinearProgressIndicator(
              value: state.downloadProgress > 0
                  ? state.downloadProgress
                  : null,
            ),
            if (state.statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  state.statusMessage!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: state.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Megálló vagy állomás keresése...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          state.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ProviderChip(
                  label: 'Mind',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ProviderChip(
                  label:
                      'Volán${state.volanStopCount > 0 ? " (${state.volanStopCount})" : ""}',
                  color: AppTheme.volan,
                  selected: _filter == 'volan',
                  onTap: () => setState(() => _filter = 'volan'),
                ),
                const SizedBox(width: 8),
                ProviderChip(
                  label: 'MÁV',
                  color: AppTheme.mav,
                  selected: _filter == 'mav',
                  onTap: () => setState(() => _filter = 'mav'),
                ),
                const SizedBox(width: 8),
                ProviderChip(
                  label:
                      'Városok${state.cityStopCount > 0 ? " (${state.cityStopCount})" : ""}',
                  color: AppTheme.primary,
                  selected: _filter == 'city',
                  onTap: () => setState(() => _filter = 'city'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (state.volanStopCount == 0 && !state.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: AppTheme.volan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => state.refreshVolanGtfs(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.download_rounded, color: AppTheme.volan),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Volán megállók letöltése (~100 MB)\nEgy érintés a frissítéshez',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.volan),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: stops.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Nincs találat',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return StopTile(
                        stop: stop,
                        isFavorite: state.isFavorite(stop),
                        onTap: () {
                          state.selectStop(stop);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DeparturesScreen(stop: stop),
                            ),
                          );
                        },
                        onFavorite: () => state.toggleFavorite(stop),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, AppState state) {
    showAboutDialog(
      context: context,
      applicationName: 'Menetrend+',
      applicationVersion: '0.1.0',
      applicationLegalese:
          'Volánbusz + MÁV menetrend\nNem hivatalos alkalmazás',
      children: [
        const SizedBox(height: 12),
        Text(
          'Adatforrások:\n'
          '• Volánbusz GTFS (gtfs.kti.hu)\n'
          '• MÁV nem hivatalos API (nzx.hu)\n\n'
          'Volán megállók: ${state.volanStopCount}',
        ),
      ],
    );
  }
}