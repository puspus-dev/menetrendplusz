import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProviderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const ProviderChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primary;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: effectiveColor.withOpacity(0.2),
      checkmarkColor: effectiveColor,
      labelStyle: TextStyle(
        color: selected ? effectiveColor : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: selected ? BorderSide(color: effectiveColor) : null,
    );
  }
}