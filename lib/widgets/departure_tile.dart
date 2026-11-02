import 'package:flutter/material.dart';
import '../models/departure.dart';
import '../theme/app_theme.dart';

class DepartureTile extends StatelessWidget {
  final Departure departure;

  const DepartureTile({super.key, required this.departure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMav = departure.provider == 'mav';
    final delayColor = departure.isCancelled
        ? Colors.grey
        : departure.isDelayed
            ? AppTheme.accent
            : AppTheme.secondary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isMav ? AppTheme.mav.withOpacity(0.12) : AppTheme.volan.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              departure.displayTime,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isMav ? AppTheme.mav : AppTheme.volan,
              ),
            ),
            if (departure.platform != null)
              Text(
                'vág. ${departure.platform}',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMav ? AppTheme.mav : AppTheme.volan,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              departure.line,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              departure.destination,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
              departure.isCancelled
                  ? Icons.cancel_rounded
                  : departure.isDelayed
                      ? Icons.schedule_rounded
                      : Icons.check_circle_rounded,
              size: 14,
              color: delayColor,
            ),
            const SizedBox(width: 4),
            Text(
              departure.delayText,
              style: TextStyle(
                color: delayColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (departure.vehicleType != null) ...[
              const SizedBox(width: 12),
              Icon(
                isMav ? Icons.train_rounded : Icons.directions_bus_rounded,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ],
        ),
      ),
      onTap: () {
        // TODO: detail sheet
      },
    );
  }
}