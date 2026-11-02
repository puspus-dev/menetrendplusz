import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'map_screen.dart';
import 'planner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final pages = [
      const SearchScreen(),
      const PlannerScreen(),
      const FavoritesScreen(),
      const MapScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: state.currentTab,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.currentTab,
        onDestinationSelected: state.setTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Keresés',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_rounded),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Útvonal',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Kedvencek',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Térkép',
          ),
        ],
      ),
    );
  }
}