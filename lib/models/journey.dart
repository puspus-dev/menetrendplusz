
class JourneyLeg {
  final String mode; // bus, train, walk
  final String line;
  final String fromName;
  final String toName;
  final DateTime departure;
  final DateTime arrival;
  final int? delayMinutes;
  final String provider;

  const JourneyLeg({
    required this.mode,
    required this.line,
    required this.fromName,
    required this.toName,
    required this.departure,
    required this.arrival,
    this.delayMinutes,
    required this.provider,
  });
}

class Journey {
  final String id;
  final List<JourneyLeg> legs;
  final DateTime departure;
  final DateTime arrival;
  final int durationMinutes;
  final int transfers;

  const Journey({
    required this.id,
    required this.legs,
    required this.departure,
    required this.arrival,
    required this.durationMinutes,
    required this.transfers,
  });
}