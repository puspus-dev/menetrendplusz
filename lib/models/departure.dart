class Departure {
  final String id;
  final String line;
  final String destination;
  final DateTime scheduledTime;
  final DateTime? realtimeTime;
  final int? delayMinutes;
  final String? platform;
  final String provider; // 'volan' | 'mav'
  final String? vehicleType; // bus, train, etc.
  final bool isCancelled;

  const Departure({
    required this.id,
    required this.line,
    required this.destination,
    required this.scheduledTime,
    this.realtimeTime,
    this.delayMinutes,
    this.platform,
    required this.provider,
    this.vehicleType,
    this.isCancelled = false,
  });

  bool get isDelayed => (delayMinutes ?? 0) > 0;
  bool get isOnTime => delayMinutes == null || delayMinutes == 0;

  String get displayTime {
    final t = realtimeTime ?? scheduledTime;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get delayText {
    if (isCancelled) return 'Törölve';
    if (delayMinutes == null || delayMinutes == 0) return 'Időben';
    if (delayMinutes! > 0) return '+$delayMinutes perc';
    return '${delayMinutes} perc';
  }
}