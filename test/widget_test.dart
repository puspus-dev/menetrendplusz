import 'package:flutter_test/flutter_test.dart';
import 'package:menetrend_plus/models/live_vehicle.dart';

void main() {
  test('LiveVehicle delay colors', () {
    const onTime = LiveVehicle(
      id: '1',
      label: '100',
      lat: 47.5,
      lon: 19.0,
      delayMinutes: 0,
      kind: VehicleKind.train,
      provider: 'mav',
    );
    expect(onTime.delayLabel.contains('0'), isTrue);

    const late = LiveVehicle(
      id: '2',
      label: '200',
      lat: 47.5,
      lon: 19.0,
      delayMinutes: 35,
      kind: VehicleKind.bus,
      provider: 'volan',
    );
    expect(late.delayMinutes, greaterThan(30));
  });
}
