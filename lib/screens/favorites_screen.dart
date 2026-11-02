import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../widgets/stop_tile.dart';
import 'departures_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favorites;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kedvencek'),
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Még nincsenek kedvenceid',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keresésnél a ♥ gombbal mentheted a megállókat',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final stop = favorites[index];
                return StopTile(
                  stop: stop,
                  isFavorite: true,
                  onTap: () {
                    state.selectStop(stop);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeparturesScreen(stop: stop),
                      ),
                    );
                  },
                  onFavorite: () => state.toggleFavorite(stop),
                );
              },
            ),
    );
  }
}