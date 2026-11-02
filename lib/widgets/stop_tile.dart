import 'package:flutter/material.dart';
import '../models/stop.dart';
import '../theme/app_theme.dart';
import 'provider_badge.dart';

class StopTile extends StatelessWidget {
  final Stop stop;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const StopTile({
    super.key,
    required this.stop,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isMav = stop.provider == 'mav';
    final color = ProviderBadge.colorFor(stop.provider);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            isMav ? Icons.train_rounded : Icons.directions_bus_rounded,
            color: color,
          ),
        ),
        title: Text(
          stop.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ProviderBadge(provider: stop.provider),
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? Colors.red : Colors.grey,
          ),
          onPressed: onFavorite,
        ),
      ),
    );
  }
}