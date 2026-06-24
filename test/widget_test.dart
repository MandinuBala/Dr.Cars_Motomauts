import 'package:dr_cars_fyp/app_theme.dart';
import 'package:dr_cars_fyp/main.dart';
import 'package:dr_cars_fyp/motornauts/api_error.dart';
import 'package:dr_cars_fyp/motornauts/app_config.dart';
import 'package:dr_cars_fyp/motornauts/motornauts_client.dart';
import 'package:dr_cars_fyp/screens/customer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap stops on unavailable tenant', (tester) async {
    await tester.pumpWidget(
      MotornautsApp(
        config: _config,
        client: _UnavailableTenantGateway(),
        enableLinkHandling: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tenant unavailable'), findsOneWidget);
  });

  testWidgets('OTP login requests and verifies a challenge', (tester) async {
    final gateway = _OtpGateway();
    await tester.pumpWidget(
      MotornautsApp(
        config: _config,
        client: gateway,
        enableLinkHandling: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await tester.tap(find.text('Request OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Verify and continue'));
    await tester.pumpAndSettle();

    expect(gateway.requestedOtp, isTrue);
    expect(gateway.verifiedOtp, isTrue);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('self-registration submit is gated by tenant terms', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMotornautsTheme(Brightness.light),
        home: AuthScreen(
          client: _RegistrationGateway(),
          tenantProfile: const {'name': 'Demo Motors'},
          onSignedIn: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('registration-submit')),
      500,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();

    FilledButton submitButton() {
      return tester.widget<FilledButton>(
        find.byKey(const Key('registration-submit')),
      );
    }

    expect(submitButton().onPressed, isNull);
    await tester.tap(find.text('I accept the tenant terms'));
    await tester.pumpAndSettle();
    expect(submitButton().onPressed, isNotNull);
  });
}

final _config = MotornautsConfig(
  apiBaseUrl: 'https://api.example.com/api/v1',
  tenantSlug: 'demo',
);

class _UnavailableTenantGateway implements MotornautsGateway {
  @override
  MotornautsConfig get config => _config;

  @override
  Future<Map<String, dynamic>> getPublicTenantProfile({String? tenantSlug}) {
    throw MotornautsApiException(
      type: MotornautsErrorType.notFound,
      statusCode: 404,
      message: 'Tenant not found.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OtpGateway implements MotornautsGateway {
  bool requestedOtp = false;
  bool verifiedOtp = false;
  int sessionCalls = 0;

  @override
  MotornautsConfig get config => _config;

  @override
  Future<Map<String, dynamic>> getPublicTenantProfile({
    String? tenantSlug,
  }) async {
    return const {'name': 'Demo Motors'};
  }

  @override
  Future<Map<String, dynamic>> getCustomerSession() async {
    sessionCalls += 1;
    if (sessionCalls == 1) {
      throw MotornautsApiException(
        type: MotornautsErrorType.unauthenticated,
        statusCode: 401,
        message: 'No session.',
      );
    }
    return const {'id': 'session_1'};
  }

  @override
  Future<Map<String, dynamic>> requestOtp(Map<String, dynamic> body) async {
    requestedOtp = true;
    return const {'challengeId': 'challenge_1'};
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    verifiedOtp = challengeId == 'challenge_1' && code == '123456';
    return const {
      'session': {'id': 'session_1'},
    };
  }

  @override
  Future<Map<String, dynamic>> getMyCustomerProfile() async {
    return const {'tenantCustomerId': 'cus_1', 'firstName': 'Ada'};
  }

  @override
  Future<Object?> getCustomerDashboardSummary() async {
    return const {'vehicles': 1};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RegistrationGateway implements MotornautsGateway {
  @override
  MotornautsConfig get config => _config;

  @override
  Future<Map<String, dynamic>> getSelfRegistrationAvailability() async {
    return const {'available': true, 'publicTermsCopy': 'Demo terms'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
