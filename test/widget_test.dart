import 'package:dr_cars_fyp/app_theme.dart';
import 'package:dr_cars_fyp/main.dart';
import 'package:dr_cars_fyp/motornauts/api_error.dart';
import 'package:dr_cars_fyp/motornauts/app_config.dart';
import 'package:dr_cars_fyp/motornauts/motornauts_client.dart';
import 'package:dr_cars_fyp/screens/customer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme maps THEME.md palettes and controls', () {
    final light = buildMotornautsTheme(Brightness.light);
    final lightColors = light.extension<MotornautsThemeColors>()!;
    final dark = buildMotornautsTheme(Brightness.dark);
    final darkColors = dark.extension<MotornautsThemeColors>()!;

    expect(light.scaffoldBackgroundColor, const Color(0xFFF7F3EA));
    expect(light.cardTheme.color, const Color(0xFFFFFCF5));
    expect(light.colorScheme.primary, const Color(0xFFA65F12));
    expect(lightColors.accentHover, const Color(0xFF8F4E0B));
    expect(lightColors.secondaryAccent, const Color(0xFF383B40));

    expect(dark.scaffoldBackgroundColor, const Color(0xFF0B0B0C));
    expect(dark.cardTheme.color, const Color(0xFF171719));
    expect(dark.colorScheme.primary, const Color(0xFFD98A21));
    expect(darkColors.accentHover, const Color(0xFFF0A23A));
    expect(darkColors.secondaryAccent, const Color(0xFF6F767F));

    expect(light.navigationBarTheme.height, 72);
    expect(
      light.navigationBarTheme.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
    expect(
      (light.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
          .borderSide
          .color,
      const Color(0xFFA65F12),
    );
    expect(
      dark.filledButtonTheme.style!.backgroundColor!.resolve({}),
      const Color(0xFFD98A21),
    );
    expect(
      light.filledButtonTheme.style!.minimumSize!.resolve({}),
      const Size(64, 48),
    );
    expect(light.snackBarTheme.behavior, SnackBarBehavior.floating);
  });

  testWidgets('shared cards and status tiles use themed surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMotornautsTheme(Brightness.light),
        home: const Scaffold(
          body: Column(
            children: [
              InfoCard(title: 'Card title', child: Text('Card body')),
              DataListTile(
                title: 'Invoice',
                subtitle: 'LKR 120.00',
                status: 'PAID',
                icon: Icons.receipt_long_outlined,
              ),
              EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No appointments',
                message: 'Nothing scheduled.',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Card title'), findsOneWidget);
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('No appointments'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(3));
  });

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

  testWidgets('bootstrap ignores local session restore failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MotornautsApp(
        config: _config,
        client: _BrokenSessionRestoreGateway(),
        enableLinkHandling: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tenant unavailable'), findsNothing);
    expect(find.text('OTP Login'), findsOneWidget);
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

  testWidgets('sample credentials smoke every customer flow', (tester) async {
    final gateway = _SmokeGateway();

    await tester.pumpWidget(
      MotornautsApp(
        config: _config,
        client: gateway,
        enableLinkHandling: false,
      ),
    );

    await _pumpUntilFound(tester, find.text('OTP Login'));
    await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
    await _tapVisible(tester, find.text('Request OTP'));
    await _pumpUntilFound(tester, _fieldWithLabel('6-digit code'));
    await tester.enterText(_fieldWithLabel('6-digit code'), '123456');
    await _tapVisible(tester, find.text('Verify and continue'));
    await _pumpUntilFound(tester, find.textContaining('Ada'));

    expect(gateway.requestedOtp, isTrue);
    expect(gateway.verifiedOtp, isTrue);
    expect(find.text('Demo Motors'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Active service jobs'), findsOneWidget);
    expect(find.textContaining('CBY-6268'), findsOneWidget);
    expect(find.textContaining('"tenantId"'), findsNothing);

    await _tapVisible(tester, find.text('Garage'));
    await _pumpUntilFound(tester, find.text('Vehicle summary'));
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(
      find.text(
        'Live vehicle summary is unavailable. Showing garage list totals.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('"unavailable"'), findsNothing);
    expect(find.text('CAB-1234'), findsOneWidget);
    await _tapVisible(tester, find.text('CAB-1234'));
    await _pumpUntilFound(tester, find.text('Upload document'));
    expect(find.text('Registration certificate'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('REGISTRATION_CERTIFICATE'), findsNothing);
    expect(find.textContaining('"vehicleId"'), findsNothing);
    await _scrollUntilVisible(tester, find.byTooltip('View'));
    await _tapVisible(tester, find.byTooltip('View').first);
    expect(gateway.viewedDocument, isTrue);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('Garage'));

    await _tapVisible(tester, find.byTooltip('Add vehicle'));
    await _pumpUntilFound(tester, find.text('Add vehicle'));
    await _enterField(tester, 'Registration number', 'CBA-9999');
    await _enterField(tester, 'Make', 'Honda');
    await _enterField(tester, 'Model', 'Vezel');
    await _enterField(tester, 'Year', '2023');
    await _enterField(tester, 'Current mileage', '9200');
    await _tapVisible(tester, find.text('Create vehicle'));
    expect(gateway.createdVehicle, isTrue);
    await _pumpUntilFound(tester, find.text('CBA-9999'));

    await _tapVisible(tester, find.byTooltip('Edit').first);
    await _pumpUntilFound(tester, find.text('Edit vehicle'));
    await _enterField(tester, 'Current mileage', '12345');
    await _tapVisible(tester, find.text('Save changes'));
    expect(gateway.updatedVehicle, isTrue);

    await _tapVisible(tester, find.text('Book'));
    await _pumpUntilFound(tester, find.text('New booking'));
    expect(find.text('VEHICLE & LOCATION'), findsOneWidget);
    expect(find.text('Tap to change'), findsOneWidget);
    await _enterField(tester, 'Mileage at booking', '12400');
    await _enterField(
      tester,
      'Notes / complaints',
      'Brake noise. Use sample smoke test data',
    );
    await _tapVisible(tester, find.text('Check availability'));
    expect(gateway.checkedAvailability, isTrue);
    await _tapVisible(tester, find.text('Request appointment'));
    expect(gateway.createdBooking, isTrue);
    await _pumpUntilFound(tester, find.text('2026-07-02T09:00:00Z'));
    await _tapVisible(tester, find.text('2026-07-02T09:00:00Z'));
    await _pumpUntilFound(tester, find.text('Appointment'));
    expect(find.textContaining('"appointmentId"'), findsNothing);
    await _tapVisible(tester, find.text('Cancel appointment'));
    expect(gateway.transitionedAppointment, isTrue);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('Book'));

    await _tapVisible(tester, find.text('Service'));
    await _pumpUntilFound(tester, find.text('Repair orders'));
    await _tapVisible(tester, find.text('RO-1001'));
    await _pumpUntilFound(tester, find.text('Repair order'));
    expect(find.textContaining('"repairOrderId"'), findsNothing);
    await _tapVisible(tester, find.text('Open service-history PDF'));
    expect(gateway.requestedServiceHistoryPdf, isTrue);
    await _tapVisible(tester, find.text('EST-1001'));
    await _pumpUntilFound(tester, find.text('Estimate'));
    expect(find.textContaining('"estimateId"'), findsNothing);
    await _tapVisible(tester, find.text('Open estimate PDF'));
    expect(gateway.requestedEstimatePdf, isTrue);
    await _tapVisible(tester, find.text('Approve'));
    await _enterField(tester, 'Optional note', 'Approved in smoke test');
    await _tapVisible(tester, find.text('Submit decisions'));
    expect(gateway.submittedEstimateDecision, isTrue);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('Repair order'));
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('Service'));

    await _tapVisible(tester, find.text('INV-1001'));
    await _pumpUntilFound(tester, find.text('Invoice'));
    expect(find.textContaining('"invoiceId"'), findsNothing);
    await _tapVisible(tester, find.text('Open invoice PDF'));
    expect(gateway.requestedInvoicePdf, isTrue);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('Service'));

    await _tapVisible(tester, find.text('More'));
    await _pumpUntilFound(tester, find.text('Profile'));
    await _tapVisible(tester, find.widgetWithText(DataListTile, 'Profile'));
    await _pumpUntilFound(tester, find.text('Verified account'));
    expect(find.text('Verified account'), findsOneWidget);
    await _scrollUntilVisible(tester, _fieldWithLabel('First name'));
    expect(_fieldValue(tester, 'First name'), 'Ada');
    expect(_fieldValue(tester, 'Last name'), 'Lovelace');
    await _scrollUntilVisible(tester, _fieldWithLabel('Phone number'));
    expect(find.text('+94'), findsOneWidget);
    expect(_fieldValue(tester, 'Phone number'), '770000000');
    await _scrollUntilVisible(tester, _fieldWithLabel('Street'));
    expect(_fieldValue(tester, 'Street'), '42 Engine Lane');
    expect(_fieldValue(tester, 'City'), 'Colombo');
    await _enterField(tester, 'Phone number', '770000001');
    await _scrollUntilVisible(tester, find.text('Save profile'));
    await _tapVisible(tester, find.text('Save profile'));
    expect(gateway.updatedProfile, isTrue);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));

    await _tapVisible(tester, find.text('Payment or feedback link'));
    await _enterField(
      tester,
      'Motornauts link',
      'https://links.example.com/t/demo/payment-requests/pay_1?token=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    await _tapVisible(tester, find.text('Open'));
    await _pumpUntilFound(tester, find.text('Payment request'));
    expect(find.text('Open provider checkout'), findsOneWidget);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));

    await _tapVisible(tester, find.text('Payment or feedback link'));
    await _enterField(
      tester,
      'Motornauts link',
      'motornauts://feedback/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb?tenantSlug=demo',
    );
    await _tapVisible(tester, find.text('Open'));
    await _pumpUntilFound(tester, find.text('Feedback'));
    expect(find.textContaining('"repairOrderNumber"'), findsNothing);
    await _enterField(tester, 'Comment', 'Good sample smoke test service');
    await _tapVisible(tester, find.text('Submit feedback'));
    expect(gateway.submittedFeedback, isTrue);
    await _pumpUntilFound(tester, find.text('Feedback submitted'));
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));

    await _tapVisible(tester, find.text('Compliance request'));
    await _pumpUntilFound(tester, find.text('Submit request'));
    await _enterField(tester, 'Requester name', 'Ada Lovelace');
    await _enterField(tester, 'Requester email', 'ada@example.com');
    await _enterField(tester, 'Requester phone', '+94770000001');
    await _enterField(tester, 'Summary', 'Sample smoke compliance request');
    await _tapVisible(tester, find.text('Submit request'));
    await _pumpUntilFound(tester, find.text('comp_1'));
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));

    await _tapVisible(tester, find.text('Local OBD utility'));
    await _pumpUntilFound(tester, find.text('OBD diagnostics'));
    expect(find.text('Live data'), findsOneWidget);
    await _dragListUntilVisible(tester, find.text('Trouble codes'));
    expect(find.text('Trouble codes'), findsOneWidget);
    await _dragListUntilVisible(tester, find.text('Freeze frame'));
    expect(find.text('Freeze frame'), findsOneWidget);
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));
    await _tapVisible(tester, find.text('Local 3D viewer'));
    await _pumpUntilFound(tester, find.text('Local-only 3D assets'));
    await _goBack(tester);
    await _pumpUntilFound(tester, find.text('More'));

    await _tapVisible(tester, find.text('Logout'));
    await _pumpUntilFound(tester, find.text('OTP Login'));
    expect(gateway.loggedOut, isTrue);
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

class _BrokenSessionRestoreGateway implements MotornautsGateway {
  @override
  MotornautsConfig get config => _config;

  @override
  Future<Map<String, dynamic>> getPublicTenantProfile({
    String? tenantSlug,
  }) async {
    return const {
      'tenant': {'displayName': 'Demo Motors'},
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerSession() {
    throw StateError('Secure storage unavailable.');
  }

  @override
  Future<Map<String, dynamic>> getSelfRegistrationAvailability() async {
    return const {'available': true, 'publicTermsCopy': 'Demo terms'};
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

class _SmokeGateway implements MotornautsGateway {
  bool requestedOtp = false;
  bool verifiedOtp = false;
  bool viewedDocument = false;
  bool createdVehicle = false;
  bool updatedVehicle = false;
  bool checkedAvailability = false;
  bool createdBooking = false;
  bool transitionedAppointment = false;
  bool requestedServiceHistoryPdf = false;
  bool requestedEstimatePdf = false;
  bool submittedEstimateDecision = false;
  bool requestedInvoicePdf = false;
  bool updatedProfile = false;
  bool submittedFeedback = false;
  bool loggedOut = false;

  bool _authenticated = false;
  String _appointmentStatus = 'REQUESTED';

  final List<Map<String, dynamic>> _vehicles = [
    {
      'vehicleId': 'veh_1',
      'registrationNumber': 'CAB-1234',
      'make': 'Toyota',
      'model': 'Camry',
      'year': 2022,
      'fuelType': 'PETROL',
      'transmission': 'AUTOMATIC',
      'currentMileage': 12000,
      'verificationStatus': 'APPROVED',
      'ownershipStatus': 'OWNED',
    },
  ];

  @override
  MotornautsConfig get config => _config;

  @override
  Future<Map<String, dynamic>> getPublicTenantProfile({
    String? tenantSlug,
  }) async {
    return const {
      'tenant': {'displayName': 'Demo Motors'},
    };
  }

  @override
  Future<Map<String, dynamic>> getSelfRegistrationAvailability() async {
    return const {'available': true, 'publicTermsCopy': 'Demo terms'};
  }

  @override
  Future<Map<String, dynamic>> requestOtp(Map<String, dynamic> body) async {
    requestedOtp =
        body['channel'] == 'EMAIL' && body['email'] == 'ada@example.com';
    return const {'challengeId': 'challenge_1'};
  }

  @override
  Future<Map<String, dynamic>> resendOtp(String challengeId) async {
    return const {'challengeId': 'challenge_1'};
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    verifiedOtp = challengeId == 'challenge_1' && code == '123456';
    _authenticated = verifiedOtp;
    return const {
      'session': {'id': 'session_1'},
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerSession() async {
    if (!_authenticated) {
      throw MotornautsApiException(
        type: MotornautsErrorType.unauthenticated,
        statusCode: 401,
        message: 'No session.',
      );
    }
    return const {'id': 'session_1'};
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
    _authenticated = false;
  }

  @override
  Future<Map<String, dynamic>> getMyCustomerProfile() async {
    return const {
      'customerProfile': {
        'tenantCustomerId': 'cus_1',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'email': 'ada@example.com',
        'phoneNumber': '+94770000000',
        'address': {'addressLine1': '42 Engine Lane', 'city': 'Colombo'},
      },
    };
  }

  @override
  Future<Map<String, dynamic>> updateMyCustomerProfile(
    Map<String, dynamic> body,
  ) async {
    updatedProfile = body['phone'] == '+94770000001';
    return getMyCustomerProfile();
  }

  @override
  Future<Object?> getCustomerDashboardSummary() async {
    return const {
      'tenantId': 'pw_anton_auto_care_tenant_primary',
      'tenantCustomerId': 'pw_anton_auto_care_tenant_customer_0220',
      'upcomingAppointments': {
        'count': 1,
        'items': [
          {
            'id': 'cmqnr5biv000d0kl4cum23v1v',
            'status': 'REQUESTED',
            'startsAt': '2026-07-01T07:30:00.000Z',
            'requestedStartAt': '2026-07-01T07:30:00.000Z',
            'vehicle': {
              'registrationNumber': 'CBY-6268',
              'make': 'Audi',
              'model': 'A3',
              'year': 2024,
            },
            'servicePackage': {'name': 'Brake Service'},
          },
        ],
      },
      'activeServiceJobs': {
        'count': 1,
        'items': [
          {
            'id': 'pw_anton_auto_care_repair_order_0220',
            'status': 'APPROVAL_RECEIVED',
            'statusChangedAt': '2026-05-21T10:30:00.000Z',
            'vehicle': {
              'registrationNumber': 'EP ANT-1219',
              'make': 'Nissan',
              'model': 'Leaf',
              'year': 2017,
            },
            'servicePackage': {'name': 'Diagnostic Scan'},
          },
        ],
      },
      'pendingApprovals': {'count': 0, 'items': []},
      'pendingPayments': {'count': 0, 'items': []},
    };
  }

  @override
  Future<Object?> listCustomerVehicles({
    int? page,
    int? pageSize,
    String? tenantCustomerId,
    String? registrationNumber,
  }) async {
    return {'vehicles': _vehicles};
  }

  @override
  Future<Object?> getVehicleSummary() async {
    throw MotornautsApiException(
      type: MotornautsErrorType.notFound,
      statusCode: 404,
      message: 'The requested resource is not available.',
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomerVehicle(
    Map<String, dynamic> body,
  ) async {
    createdVehicle = body['registrationNumber'] == 'CBA-9999';
    _vehicles.add({
      ...body,
      'vehicleId': 'veh_2',
      'verificationStatus': 'PENDING',
    });
    return _vehicles.last;
  }

  @override
  Future<Map<String, dynamic>> getCustomerVehicle(String vehicleId) async {
    return _vehicles.firstWhere(
      (vehicle) => vehicle['vehicleId'] == vehicleId,
      orElse: () => _vehicles.first,
    );
  }

  @override
  Future<Map<String, dynamic>> updateCustomerVehicle(
    String vehicleId,
    Map<String, dynamic> body,
  ) async {
    updatedVehicle = body['currentMileage'] == 12345;
    final index = _vehicles.indexWhere(
      (vehicle) => vehicle['vehicleId'] == vehicleId,
    );
    if (index != -1) {
      _vehicles[index] = {..._vehicles[index], ...body};
    }
    return getCustomerVehicle(vehicleId);
  }

  @override
  Future<Object?> listVehicleDocuments(
    String vehicleId, {
    String? documentType,
  }) async {
    return const {
      'documents': [
        {
          'documentId': 'doc_1',
          'documentType': 'INSURANCE',
          'fileName': 'insurance.pdf',
          'status': 'APPROVED',
          'mimeType': 'application/pdf',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> createVehicleDocumentViewUrl({
    required String vehicleId,
    required String documentId,
  }) async {
    viewedDocument = vehicleId == 'veh_1' && documentId == 'doc_1';
    return const {'url': 'https://example.com/documents/doc_1.pdf'};
  }

  @override
  Future<Map<String, dynamic>> createVehicleDocumentDownloadUrl({
    required String vehicleId,
    required String documentId,
  }) async {
    return const {'url': 'https://example.com/documents/doc_1.pdf'};
  }

  @override
  Future<Object?> getCustomerBookingOptions() async {
    return const {
      'branches': [
        {'branchId': 'br_1', 'name': 'Colombo'},
      ],
      'servicePackages': [
        {'servicePackageId': 'pkg_1', 'name': 'General service'},
      ],
    };
  }

  @override
  Future<Object?> getAppointmentAvailability({
    required String branchId,
    required String servicePackageId,
    required DateTime from,
    required DateTime to,
  }) async {
    checkedAvailability = branchId == 'br_1' && servicePackageId == 'pkg_1';
    return const {
      'slots': [
        {
          'label': '2026-07-03 09:00',
          'startAt': '2026-07-03T09:00:00Z',
          'endAt': '2026-07-03T10:00:00Z',
        },
      ],
    };
  }

  @override
  Future<Object?> listCustomerAppointments() async {
    return {
      'appointments': [
        {
          'appointmentId': 'app_1',
          'requestedStartAt': '2026-07-02T09:00:00Z',
          'servicePackageName': 'General service',
          'branchName': 'Colombo',
          'vehicleRegistrationNumber': 'CAB-1234',
          'status': _appointmentStatus,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> createCustomerBooking(
    Map<String, dynamic> body,
  ) async {
    createdBooking =
        body['vehicleId'] == 'veh_1' &&
        body['branchId'] == 'br_1' &&
        body['servicePackageId'] == 'pkg_1';
    return const {'appointmentId': 'app_2'};
  }

  @override
  Future<Map<String, dynamic>> getCustomerAppointment(
    String appointmentId,
  ) async {
    return {
      'appointmentId': appointmentId,
      'status': _appointmentStatus,
      'requestedStartAt': '2026-07-02T09:00:00Z',
      'allowedTransitions': [
        {'status': 'CANCELLED', 'label': 'Cancel appointment'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> transitionCustomerAppointmentStatus({
    required String appointmentId,
    required Map<String, dynamic> body,
  }) async {
    transitionedAppointment =
        appointmentId == 'app_1' && body['status'] == 'CANCELLED';
    _appointmentStatus = body['status']?.toString() ?? _appointmentStatus;
    return getCustomerAppointment(appointmentId);
  }

  @override
  Future<Object?> listCustomerRepairOrders() async {
    return const {
      'repairOrders': [
        {
          'repairOrderId': 'ro_1',
          'repairOrderNumber': 'RO-1001',
          'vehicleRegistrationNumber': 'CAB-1234',
          'status': 'IN_PROGRESS',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerRepairOrder(
    String repairOrderId,
  ) async {
    return const {
      'repairOrderId': 'ro_1',
      'repairOrderNumber': 'RO-1001',
      'status': 'IN_PROGRESS',
      'estimates': [
        {
          'estimateId': 'est_1',
          'estimateNumber': 'EST-1001',
          'status': 'PENDING',
        },
      ],
    };
  }

  @override
  Future<Object?> listCustomerRepairOrderTimeline(String repairOrderId) async {
    return const {
      'events': [
        {'title': 'Inspection started', 'message': 'Vehicle checked in.'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerServiceHistoryPdfState(
    String repairOrderId,
  ) async {
    requestedServiceHistoryPdf = repairOrderId == 'ro_1';
    return const {'available': true};
  }

  @override
  Future<Map<String, dynamic>> createCustomerServiceHistoryPdfDownloadUrl(
    String repairOrderId, {
    String disposition = 'attachment',
  }) async {
    return const {'url': 'https://example.com/service-history.pdf'};
  }

  @override
  Future<Map<String, dynamic>> getCustomerEstimate({
    required String repairOrderId,
    required String estimateId,
  }) async {
    return const {
      'estimateId': 'est_1',
      'estimateNumber': 'EST-1001',
      'estimateVersion': 1,
      'status': 'PENDING',
      'lineItems': [
        {
          'estimateLineItemId': 'line_1',
          'description': 'Brake pad replacement',
          'currency': 'LKR',
          'amountMinor': 250000,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerEstimatePdfState({
    required String repairOrderId,
    required String estimateId,
  }) async {
    requestedEstimatePdf = estimateId == 'est_1';
    return const {'available': true};
  }

  @override
  Future<Map<String, dynamic>> createCustomerEstimatePdfDownloadUrl({
    required String repairOrderId,
    required String estimateId,
    String disposition = 'attachment',
  }) async {
    return const {'url': 'https://example.com/estimate.pdf'};
  }

  @override
  Future<Map<String, dynamic>> submitCustomerEstimateDecisions({
    required String repairOrderId,
    required String estimateId,
    required Map<String, dynamic> body,
  }) async {
    final decisions = body['decisions'];
    submittedEstimateDecision =
        estimateId == 'est_1' &&
        decisions is List &&
        decisions.isNotEmpty &&
        decisions.first['status'] == 'APPROVED';
    return const {'status': 'SUBMITTED'};
  }

  @override
  Future<Object?> listCustomerInvoices({int? page, int? pageSize}) async {
    return const {
      'invoices': [
        {
          'invoiceId': 'inv_1',
          'invoiceNumber': 'INV-1001',
          'currency': 'LKR',
          'amountMinor': 180000,
          'status': 'UNPAID',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerInvoice(String invoiceId) async {
    return const {
      'invoiceId': 'inv_1',
      'invoiceNumber': 'INV-1001',
      'currency': 'LKR',
      'amountMinor': 180000,
      'status': 'UNPAID',
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerInvoicePdfState(
    String invoiceId,
  ) async {
    requestedInvoicePdf = invoiceId == 'inv_1';
    return const {'available': true};
  }

  @override
  Future<Map<String, dynamic>> createCustomerInvoicePdfDownloadUrl(
    String invoiceId, {
    String disposition = 'attachment',
  }) async {
    return const {'url': 'https://example.com/invoice.pdf'};
  }

  @override
  Future<Map<String, dynamic>> getCustomerPaymentRequest({
    required String tenantSlug,
    required String paymentRequestId,
    required String token,
  }) async {
    return const {
      'id': 'pay_1',
      'tenantName': 'Demo Motors',
      'status': 'PENDING',
      'amountMinor': 180000,
      'currency': 'LKR',
      'expiresAt': '2026-07-05T00:00:00Z',
      'providerHandoff': {
        'action': 'https://example.com/pay',
        'fields': {'token': 'sample'},
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getCustomerFeedbackRequest({
    required String tenantSlug,
    required String token,
  }) async {
    return const {
      'repairOrderNumber': 'RO-1001',
      'vehicleRegistrationNumber': 'CAB-1234',
    };
  }

  @override
  Future<Map<String, dynamic>> submitCustomerFeedback({
    required String tenantSlug,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    submittedFeedback = body['rating'] == 5 && body['comment'] is String;
    return const {'status': 'SUBMITTED'};
  }

  @override
  Future<Map<String, dynamic>> submitTenantComplianceRequest(
    Map<String, dynamic> body,
  ) async {
    return const {'requestId': 'comp_1'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _goBack(WidgetTester tester) async {
  final backButton = find.byTooltip('Back');
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
  } else {
    await tester.pageBack();
  }
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _dragListUntilVisible(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView).last;
  for (
    var attempt = 0;
    attempt < 8 && finder.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.drag(list, const Offset(0, -320), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets);
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final finder = _fieldWithLabel(label).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      return widget.decoration?.labelText == label;
    }
    return false;
  });
}

String _fieldValue(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(_fieldWithLabel(label).first);
  return field.controller?.text ?? '';
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
