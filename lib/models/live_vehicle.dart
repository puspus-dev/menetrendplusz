import 'package:flutter/material.dart';

enum VehicleKind { train, bus }

class LiveVehicle {
  final String id;
  final String label; // vonatszám / járatszám / rendszám
  final String? headsign;
  final double lat;
  final double lon;
  final int? delayMinutes; // null = ismeretlen
  final double? speedKmh;
  final VehicleKind kind;
  final String provider; // mav | volan
  final String? model;
  final Map<String, dynamic>? extra;

  const LiveVehicle({
    required this.id,
    required this.label,
    this.headsign,
    required this.lat,
    required this.lon,
    this.delayMinutes,
    this.speedKmh,
    required this.kind,
    required this.provider,
    this.model,
    this.extra,
  });

  /// Zöld <10, sárga 10–20, narancs 20–30, piros >30, szürke ha nincs adat
  Color get delayColor {
    final d = delayMinutes;
    if (d == null) return Colors.blueGrey;
    if (d < 10) return const Color(0xFF2E7D32); // zöld
    if (d <= 20) return const Color(0xFFF9A825); // sárga
    if (d <= 30) return const Color(0xFFEF6C00); // narancs
    return const Color(0xFFC62828); // piros
  }

  String get delayLabel {
    final d = delayMinutes;
    if (d == null) return 'Késés: nincs adat';
    if (d <= 0) return 'Időben (0 perc késés)';
    return 'Késés: $d perc';
  }

  IconData get icon =>
      kind == VehicleKind.train ? Icons.train_rounded : Icons.directions_bus_rounded;
}