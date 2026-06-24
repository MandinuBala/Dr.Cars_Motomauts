import 'dart:convert';

import 'package:dr_cars_fyp/motornauts/api_error.dart';
import 'package:dr_cars_fyp/motornauts/app_config.dart';
import 'package:dr_cars_fyp/motornauts/motornauts_client.dart';
import 'package:dr_cars_fyp/motornauts/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('stores OTP cookie and sends it on later customer calls', () async {
    final store = MemoryMotornautsSessionStore();
    final requests = <http.Request>[];
    final client = MotornautsClient(
      config: MotornautsConfig(
        apiBaseUrl: 'https://api.example.com/api/v1',
        tenantSlug: 'demo',
      ),
      sessionStore: store,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/customer-auth/otp/verify')) {
          return http.Response(
            jsonEncode({
              'data': {
                'session': {'id': 's_1', 'expiresAt': '2026-06-25T00:00:00Z'},
              },
            }),
            200,
            headers: {
              'set-cookie': 'motornauts_customer_session=session_1; HttpOnly',
            },
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'tenantCustomerId': 'cus_1'},
          }),
          200,
        );
      }),
    );

    await client.verifyOtp(challengeId: 'challenge_1', code: '123456');
    await client.getMyCustomerProfile();

    expect(await store.readCookie(), 'motornauts_customer_session=session_1');
    expect(
      requests.last.headers['Cookie'],
      'motornauts_customer_session=session_1',
    );
    expect(requests.first.url.path, '/api/v1/t/demo/customer-auth/otp/verify');
  });

  test('clears cookie on 401 and exposes typed API error', () async {
    final store = MemoryMotornautsSessionStore();
    await store.writeCookie('motornauts_customer_session=session_1');
    final client = MotornautsClient(
      config: MotornautsConfig(
        apiBaseUrl: 'https://api.example.com/api/v1',
        tenantSlug: 'demo',
      ),
      sessionStore: store,
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': 'unauthenticated',
            'message': 'Session expired.',
            'messageKey': 'errors.unauthenticated',
            'requestId': 'req_401',
          }),
          401,
        );
      }),
    );

    await expectLater(
      client.getCustomerSession(),
      throwsA(
        isA<MotornautsApiException>().having(
          (error) => error.type,
          'type',
          MotornautsErrorType.unauthenticated,
        ),
      ),
    );
    expect(await store.readCookie(), isNull);
  });

  test('covers documented endpoint paths without old DR.Cars routes', () async {
    final paths = <String>[];
    final client = MotornautsClient(
      config: MotornautsConfig(
        apiBaseUrl: 'https://api.example.com/api/v1',
        tenantSlug: 'demo',
      ),
      sessionStore: MemoryMotornautsSessionStore(),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode({'data': {}}), 200);
      }),
    );

    await client.getPublicTenantProfile();
    await client.requestOtp({'channel': 'EMAIL', 'email': 'a@example.com'});
    await client.getSelfRegistrationAvailability();
    await client.getCustomerSession();
    await client.getMyCustomerProfile();
    await client.listCustomerVehicles();
    await client.getVehicleSummary();
    await client.listVehicleDocuments('veh_1');
    await client.getCustomerBookingOptions();
    await client.getAppointmentAvailability(
      branchId: 'br_1',
      servicePackageId: 'pkg_1',
      from: DateTime.utc(2026),
      to: DateTime.utc(2026, 1, 2),
    );
    await client.listCustomerAppointments();
    await client.getCustomerDashboardSummary();
    await client.listCustomerRepairOrders();
    await client.listCustomerRepairOrderTimeline('ro_1');
    await client.getCustomerEstimate(
      repairOrderId: 'ro_1',
      estimateId: 'est_1',
    );
    await client.listCustomerInvoices();
    await client.getCustomerPaymentRequest(
      tenantSlug: 'demo',
      paymentRequestId: 'pay_1',
      token: List.filled(32, 'a').join(),
    );
    await client.getCustomerFeedbackRequest(
      tenantSlug: 'demo',
      token: List.filled(32, 'b').join(),
    );
    await client.submitTenantComplianceRequest({
      'requestType': 'DATA_ACCESS',
      'summary': 'Please export my data.',
      'evidence': {},
      'sourceEntityType': 'CUSTOMER_MOBILE_APP',
    });

    expect(paths, everyElement(startsWith('/api/v1/t/demo/')));
    expect(paths.join('\n'), isNot(contains('/login')));
    expect(paths.join('\n'), isNot(contains('/service-receipts')));
    expect(paths.join('\n'), isNot(contains('/service-records')));
  });
}
