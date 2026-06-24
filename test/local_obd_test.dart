import 'package:dr_cars_fyp/obd/local_obd.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local OBD parser', () {
    test('parses live PID values from ELM responses', () {
      expect(parseObdPidValue('41 0C 1A F8', '0C'), 1726);
      expect(parseObdPidValue('41 0D 34', '0D'), 52);
      expect(parseObdPidValue('41 05 62', '05'), 58);
      expect(parseObdPidValue('41 04 80', '04')!.round(), 50);
      expect(parseObdPidValue('41 42 36 B0', '42'), 14);
      expect(parseObdPidValue('NO DATA', '0C'), isNull);
    });

    test('decodes stored and pending trouble codes', () {
      final stored = parseDiagnosticTroubleCodes(
        '43 01 33 03 00 00 00',
        status: 'Stored',
      );
      final pending = parseDiagnosticTroubleCodes(
        '47 01 71 00 00',
        status: 'Pending',
      );

      expect(stored.map((code) => code.code), ['P0133', 'P0300']);
      expect(stored.first.description, contains('Oxygen sensor'));
      expect(pending.single.code, 'P0171');
      expect(pending.single.status, 'Pending');
    });

    test('parses freeze-frame trigger code and mode 02 PID values', () {
      expect(parseFreezeFrameTroubleCode('42 02 01 33'), 'P0133');
      expect(parseObdPidValue('42 0C 1C 48', '0C', mode: '42'), 1810);
      expect(parseObdPidValue('42 0D 38', '0D', mode: '42'), 56);
    });
  });

  group('demo OBD transport', () {
    test('runs a local command flow without hardware', () async {
      final transport = DemoObdTransport();
      await transport.connect(
        const ObdAdapter(
          id: 'demo-elm327',
          name: 'Demo ELM327 BLE',
          isDemo: true,
        ),
      );

      final rpm = parseObdPidValue(await transport.send('010C'), '0C');
      final codes = parseDiagnosticTroubleCodes(await transport.send('03'));

      expect(transport.isConnected, isTrue);
      expect(rpm, greaterThan(0));
      expect(codes.map((code) => code.code), containsAll(['P0133', 'P0300']));

      await transport.disconnect();
      expect(transport.isConnected, isFalse);
    });
  });
}
