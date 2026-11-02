import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProviderBadge extends StatelessWidget {
  final String provider;

  const ProviderBadge({super.key, required this.provider});

  static String labelFor(String provider) {
    switch (provider) {
      case 'mav':
        return 'MÁV';
      case 'volan':
        return 'Volán';
      case 'veszprem':
        return 'Veszprém';
      case 'szombathely':
        return 'Szombathely';
      case 'szekesfehervar':
        return 'Székesfehérvár';
      case 'szeged':
        return 'Szeged';
      case 'pecs':
        return 'Pécs';
      case 'miskolc':
        return 'Miskolc';
      case 'eger':
        return 'Eger';
      case 'dunaujvaros':
        return 'Dunaújváros';
      default:
        return provider;
    }
  }

  static Color colorFor(String provider) {
    switch (provider) {
      case 'mav':
        return AppTheme.mav;
      case 'volan':
        return AppTheme.volan;
      case 'miskolc':
        return const Color(0xFF2E7D32);
      case 'pecs':
        return const Color(0xFF6A1B9A);
      case 'szeged':
        return const Color(0xFF00838F);
      case 'veszprem':
        return const Color(0xFFEF6C00);
      case 'szombathely':
        return const Color(0xFF5D4037);
      case 'szekesfehervar':
        return const Color(0xFF3949AB);
      case 'eger':
        return const Color(0xFFC62828);
      case 'dunaujvaros':
        return const Color(0xFF455A64);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(provider);
    final label = labelFor(provider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}