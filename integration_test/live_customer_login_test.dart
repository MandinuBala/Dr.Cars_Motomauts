import 'package:dr_cars_fyp/main.dart';
import 'package:dr_cars_fyp/motornauts/app_config.dart';
import 'package:dr_cars_fyp/motornauts/motornauts_client.dart';
import 'package:dr_cars_fyp/motornauts/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _liveCustomerEmail = String.fromEnvironment('LIVE_CUSTOMER_EMAIL');
const _liveCustomerOtp = String.fromEnvironment('LIVE_CUSTOMER_OTP');
final _hasLiveCredentials =
    _liveCustomerEmail.isNotEmpty && _liveCustomerOtp.isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live customer can sign in with OTP and load customer screens',
    (tester) async {
      final config = MotornautsConfig.fromEnvironment();
      final client = MotornautsClient(
        config: config,
        sessionStore: MemoryMotornautsSessionStore(),
      );

      await tester.pumpWidget(
        MotornautsApp(
          config: config,
          client: client,
          enableLinkHandling: false,
        ),
      );

      await _pumpUntilFound(tester, find.text('OTP Login'));
      await _pumpUntilFound(tester, find.text('Isira Motors'));

      await tester.enterText(
        find.byType(TextFormField).first,
        _liveCustomerEmail,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Request OTP'));

      await _pumpUntilFound(tester, _fieldWithLabel('6-digit code'));
      await tester.enterText(_fieldWithLabel('6-digit code'), _liveCustomerOtp);
      final verifyButton = find.widgetWithText(
        FilledButton,
        'Verify and continue',
      );
      await tester.ensureVisible(verifyButton);
      await tester.pumpAndSettle();
      await tester.tap(verifyButton);

      await _pumpUntilFound(tester, find.text('Customer profile'));
      await _pumpUntilFound(tester, find.text('Dashboard summary'));

      await tester.tap(find.text('Garage'));
      await _pumpUntilFound(tester, find.text('Vehicle summary'));
      expect(find.text('No vehicles'), findsNothing);

      await tester.tap(find.text('Service'));
      await _pumpUntilFound(tester, find.text('Repair orders'));
      expect(find.text('No repair orders'), findsNothing);
    },
    skip: !_hasLiveCredentials,
  );
}

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      return widget.decoration?.labelText == label;
    }
    return false;
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  await tester.pumpAndSettle();
  expect(finder, findsWidgets);
}
