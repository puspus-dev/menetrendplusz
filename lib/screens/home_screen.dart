import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'map_screen.dart';
import 'planner_screen.dart';
import 'feeds_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final pages = [
      const SearchScreen(),
      const FavoritesScreen(),
      const MapScreen(),
      const PlannerScreen(),
      const FeedsScreen(),
    ];

    final idx = state.currentTab.clamp(0, pages.length - 1);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: idx,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.navigationBarTheme.backgroundColor ??
              theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: state.setTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Keresés',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Kedvencek',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.public_rounded),
              label: 'Térkép',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_rounded),
              selectedIcon: Icon(Icons.alt_route_rounded),
              label: 'Útvonal',
            ),
            NavigationDestination(
              icon: Icon(Icons.layers_outlined),
              selectedIcon: Icon(Icons.layers_rounded),
              label: 'Városok',
            ),
          ],
        ),
      ),
    );
  }
}
