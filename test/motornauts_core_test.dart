import 'dart:convert';

import 'package:dr_cars_fyp/motornauts/api_error.dart';
import 'package:dr_cars_fyp/motornauts/app_config.dart';
import 'package:dr_cars_fyp/motornauts/idempotency.dart';
import 'package:dr_cars_fyp/motornauts/link_parser.dart';
import 'package:dr_cars_fyp/motornauts/payloads.dart';
import 'package:dr_cars_fyp/motornauts/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MotornautsConfig', () {
    test('normalizes base URL and URL-encodes tenant paths', () {
      final config = MotornautsConfig(
        apiBaseUrl: 'https://api.example.com/api/v1///',
        tenantSlug: 'isira motors',
      );

      expect(config.apiBaseUrl, 'https://api.example.com/api/v1');
      expect(
        config
            .tenantUri('vehicles', query: {'registrationNumber': 'CAB 123'})
            .toString(),
        'https://api.example.com/api/v1/t/isira%20motors/vehicles?registrationNumber=CAB+123',
      );
    });
  });

  group('errors and cookies', () {
    test('maps validation details into field messages', () {
      final error = MotornautsApiException.fromResponse(
        422,
        jsonEncode({
          'error': 'validation_problem',
          'message': 'Request validation failed.',
          'messageKey': 'errors.validationProblem',
          'requestId': 'req_1',
          'details': {
            'fieldErrors': {
              'email': ['Invalid email'],
              'phone': 'Invalid phone',
            },
          },
        }),
      );

      expect(error.type, MotornautsErrorType.validationProblem);
      expect(error.fieldMessages['email'], 'Invalid email');
      expect(error.fieldMessages['phone'], 'Invalid phone');
    });

    test('extracts only the Motornauts customer session cookie', () {
      final cookie = extractCustomerSessionCookie({
        'set-cookie':
            'foo=1; Path=/, motornauts_customer_session=abc123; HttpOnly; Path=/',
      });

      expect(cookie, 'motornauts_customer_session=abc123');
    });
  });

  group('payloads and idempotency', () {
    test('omits empty optional values from payload helpers', () {
      final body = MotornautsPayloads.profileUpdate(
        firstName: 'Ada',
        lastName: '',
        city: 'Colombo',
      );

      expect(body, {'firstName': 'Ada', 'city': 'Colombo'});
    });

    test('creates stable-format idempotency keys', () {
      final key = newIdempotencyKey(
        now: DateTime.utc(2026, 6, 24),
        randomValue: 255,
      );

      expect(key, 'mobile-1782259200000000-ff');
    });
  });

  group('link parser', () {
    test('parses payment and feedback links', () {
      final paymentToken = List.filled(32, 'a').join();
      final feedbackToken = List.filled(32, 'b').join();
      final payment = parseMotornautsLink(
        Uri.parse(
          'https://links.example.com/t/demo/payment-requests/pay_1?token=$paymentToken',
        ),
      );
      final feedback = parseMotornautsLink(
        Uri.parse('motornauts://feedback/$feedbackToken?tenantSlug=demo'),
      );

      expect(payment?.type, MotornautsLinkType.payment);
      expect(payment?.tenantSlug, 'demo');
      expect(payment?.paymentRequestId, 'pay_1');
      expect(feedback?.type, MotornautsLinkType.feedback);
      expect(feedback?.feedbackToken, feedbackToken);
    });
  });
}
