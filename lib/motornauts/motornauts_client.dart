import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_error.dart';
import 'app_config.dart';
import 'session_store.dart';

abstract class MotornautsGateway {
  MotornautsConfig get config;

  Future<Map<String, dynamic>> getPublicTenantProfile({String? tenantSlug});

  Future<Uint8List> getPublicTenantLogo({String? tenantSlug});

  Future<Map<String, dynamic>> getSelfRegistrationAvailability();

  Future<Map<String, dynamic>> submitSelfRegistration(
    Map<String, dynamic> body,
  );

  Future<Map<String, dynamic>> requestOtp(Map<String, dynamic> body);

  Future<Map<String, dynamic>> resendOtp(String challengeId);

  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  });

  Future<Map<String, dynamic>> getCustomerSession();

  Future<void> logout();

  Future<Map<String, dynamic>> getMyCustomerProfile();

  Future<Map<String, dynamic>> updateMyCustomerProfile(
    Map<String, dynamic> body,
  );

  Future<Object?> listCustomerVehicles({
    int? page,
    int? pageSize,
    String? tenantCustomerId,
    String? registrationNumber,
  });

  Future<Object?> getVehicleSummary();

  Future<Map<String, dynamic>> createCustomerVehicle(Map<String, dynamic> body);

  Future<Map<String, dynamic>> getCustomerVehicle(String vehicleId);

  Future<Map<String, dynamic>> updateCustomerVehicle(
    String vehicleId,
    Map<String, dynamic> body,
  );

  Future<Object?> listVehicleDocuments(
    String vehicleId, {
    String? documentType,
  });

  Future<Map<String, dynamic>> createVehicleDocumentUploadIntent(
    String vehicleId,
    Map<String, dynamic> body,
  );

  Future<void> uploadSignedObject({
    required String url,
    required List<int> bytes,
    Map<String, String> headers = const {},
    String method = 'PUT',
  });

  Future<Map<String, dynamic>> completeVehicleDocumentUpload({
    required String vehicleId,
    required String documentId,
  });

  Future<Map<String, dynamic>> createVehicleDocumentViewUrl({
    required String vehicleId,
    required String documentId,
  });

  Future<Map<String, dynamic>> createVehicleDocumentDownloadUrl({
    required String vehicleId,
    required String documentId,
  });

  Future<Object?> getCustomerBookingOptions();

  Future<Object?> getAppointmentAvailability({
    required String branchId,
    required String servicePackageId,
    required DateTime from,
    required DateTime to,
  });

  Future<Object?> listCustomerAppointments();

  Future<Map<String, dynamic>> createCustomerBooking(Map<String, dynamic> body);

  Future<Map<String, dynamic>> getCustomerAppointment(String appointmentId);

  Future<Map<String, dynamic>> transitionCustomerAppointmentStatus({
    required String appointmentId,
    required Map<String, dynamic> body,
  });

  Future<Object?> getCustomerDashboardSummary();

  Future<Object?> listCustomerRepairOrders();

  Future<Map<String, dynamic>> getCustomerRepairOrder(String repairOrderId);

  Future<Object?> listCustomerRepairOrderTimeline(String repairOrderId);

  Future<Map<String, dynamic>> getCustomerEstimate({
    required String repairOrderId,
    required String estimateId,
  });

  Future<Map<String, dynamic>> submitCustomerEstimateDecisions({
    required String repairOrderId,
    required String estimateId,
    required Map<String, dynamic> body,
  });

  Future<Map<String, dynamic>> getCustomerInvoicePdfState(String invoiceId);

  Future<Map<String, dynamic>> createCustomerInvoicePdfDownloadUrl(
    String invoiceId, {
    String disposition = 'attachment',
  });

  Future<Map<String, dynamic>> getCustomerEstimatePdfState({
    required String repairOrderId,
    required String estimateId,
  });

  Future<Map<String, dynamic>> createCustomerEstimatePdfDownloadUrl({
    required String repairOrderId,
    required String estimateId,
    String disposition = 'attachment',
  });

  Future<Map<String, dynamic>> getCustomerInspectionReportPdfState({
    required String repairOrderId,
    required String inspectionId,
  });

  Future<Map<String, dynamic>> createCustomerInspectionReportPdfDownloadUrl({
    required String repairOrderId,
    required String inspectionId,
    String disposition = 'attachment',
  });

  Future<Map<String, dynamic>> getCustomerServiceHistoryPdfState(
    String repairOrderId,
  );

  Future<Map<String, dynamic>> createCustomerServiceHistoryPdfDownloadUrl(
    String repairOrderId, {
    String disposition = 'attachment',
  });

  Future<Object?> listCustomerInvoices({int? page, int? pageSize});

  Future<Map<String, dynamic>> getCustomerInvoice(String invoiceId);

  Future<Map<String, dynamic>> getCustomerPaymentRequest({
    required String tenantSlug,
    required String paymentRequestId,
    required String token,
  });

  Future<Map<String, dynamic>> getCustomerFeedbackRequest({
    required String tenantSlug,
    required String token,
  });

  Future<Map<String, dynamic>> submitCustomerFeedback({
    required String tenantSlug,
    required String token,
    required Map<String, dynamic> body,
  });

  Future<Map<String, dynamic>> submitTenantComplianceRequest(
    Map<String, dynamic> body,
  );
}

class MotornautsClient implements MotornautsGateway {
  MotornautsClient({
    required this.config,
    http.Client? httpClient,
    MotornautsSessionStore? sessionStore,
  }) : _httpClient = httpClient ?? http.Client(),
       _sessionStore = sessionStore ?? const SecureMotornautsSessionStore();

  @override
  final MotornautsConfig config;
  final http.Client _httpClient;
  final MotornautsSessionStore _sessionStore;
  String? _sessionCookieFallback;

  @override
  Future<Map<String, dynamic>> getPublicTenantProfile({
    String? tenantSlug,
  }) async {
    return _map(
      await _request(
        'GET',
        'public-profile',
        auth: false,
        tenantSlug: tenantSlug,
      ),
    );
  }

  @override
  Future<Uint8List> getPublicTenantLogo({String? tenantSlug}) async {
    final response = await _rawRequest(
      'GET',
      'public-profile/logo',
      auth: false,
      tenantSlug: tenantSlug,
      accept: 'image/*',
    );
    return response.bodyBytes;
  }

  @override
  Future<Map<String, dynamic>> getSelfRegistrationAvailability() async {
    return _map(
      await _request('GET', 'customer-self-registration', auth: false),
    );
  }

  @override
  Future<Map<String, dynamic>> submitSelfRegistration(
    Map<String, dynamic> body,
  ) async {
    return _map(
      await _request(
        'POST',
        'customer-self-registration-requests',
        body: body,
        auth: false,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> requestOtp(Map<String, dynamic> body) async {
    return _map(
      await _request(
        'POST',
        'customer-auth/otp/request',
        body: body,
        auth: false,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> resendOtp(String challengeId) async {
    return _map(
      await _request(
        'POST',
        'customer-auth/otp/resend',
        body: {'challengeId': challengeId},
        auth: false,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    return _map(
      await _request(
        'POST',
        'customer-auth/otp/verify',
        body: {'challengeId': challengeId, 'code': code},
        auth: false,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerSession() async {
    return _map(await _request('GET', 'customer-auth/session'));
  }

  @override
  Future<void> logout() async {
    try {
      await _request('POST', 'customer-auth/logout');
    } finally {
      await _sessionStore.clearCookie();
    }
  }

  @override
  Future<Map<String, dynamic>> getMyCustomerProfile() async {
    return _map(await _request('GET', 'customers/me'));
  }

  @override
  Future<Map<String, dynamic>> updateMyCustomerProfile(
    Map<String, dynamic> body,
  ) async {
    return _map(await _request('PATCH', 'customers/me', body: body));
  }

  @override
  Future<Object?> listCustomerVehicles({
    int? page,
    int? pageSize,
    String? tenantCustomerId,
    String? registrationNumber,
  }) {
    return _request(
      'GET',
      'vehicles',
      query: {
        'page': page?.toString(),
        'pageSize': pageSize?.toString(),
        'tenantCustomerId': tenantCustomerId,
        'registrationNumber': registrationNumber,
      },
    );
  }

  @override
  Future<Object?> getVehicleSummary() => _request('GET', 'vehicles/summary');

  @override
  Future<Map<String, dynamic>> createCustomerVehicle(
    Map<String, dynamic> body,
  ) async {
    return _map(await _request('POST', 'vehicles', body: body));
  }

  @override
  Future<Map<String, dynamic>> getCustomerVehicle(String vehicleId) async {
    return _map(
      await _request('GET', 'vehicles/${Uri.encodeComponent(vehicleId)}'),
    );
  }

  @override
  Future<Map<String, dynamic>> updateCustomerVehicle(
    String vehicleId,
    Map<String, dynamic> body,
  ) async {
    return _map(
      await _request(
        'PATCH',
        'vehicles/${Uri.encodeComponent(vehicleId)}',
        body: body,
      ),
    );
  }

  @override
  Future<Object?> listVehicleDocuments(
    String vehicleId, {
    String? documentType,
  }) {
    return _request(
      'GET',
      'vehicles/${Uri.encodeComponent(vehicleId)}/documents',
      query: {'documentType': documentType},
    );
  }

  @override
  Future<Map<String, dynamic>> createVehicleDocumentUploadIntent(
    String vehicleId,
    Map<String, dynamic> body,
  ) async {
    return _map(
      await _request(
        'POST',
        'vehicles/${Uri.encodeComponent(vehicleId)}/documents/upload-intents',
        body: body,
      ),
    );
  }

  @override
  Future<void> uploadSignedObject({
    required String url,
    required List<int> bytes,
    Map<String, String> headers = const {},
    String method = 'PUT',
  }) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers);
    request.bodyBytes = bytes;
    final response = await _send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SignedUploadException(response.statusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> completeVehicleDocumentUpload({
    required String vehicleId,
    required String documentId,
  }) async {
    return _map(
      await _request(
        'POST',
        'vehicles/${Uri.encodeComponent(vehicleId)}/documents/'
            '${Uri.encodeComponent(documentId)}/complete-upload',
        body: const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createVehicleDocumentViewUrl({
    required String vehicleId,
    required String documentId,
  }) async {
    return _map(
      await _request(
        'POST',
        'vehicles/${Uri.encodeComponent(vehicleId)}/documents/'
            '${Uri.encodeComponent(documentId)}/view-url',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createVehicleDocumentDownloadUrl({
    required String vehicleId,
    required String documentId,
  }) async {
    return _map(
      await _request(
        'POST',
        'vehicles/${Uri.encodeComponent(vehicleId)}/documents/'
            '${Uri.encodeComponent(documentId)}/download-url',
      ),
    );
  }

  @override
  Future<Object?> getCustomerBookingOptions() {
    return _request('GET', 'appointments/booking-options');
  }

  @override
  Future<Object?> getAppointmentAvailability({
    required String branchId,
    required String servicePackageId,
    required DateTime from,
    required DateTime to,
  }) {
    return _request(
      'GET',
      'appointments/availability',
      query: {
        'branchId': branchId,
        'servicePackageId': servicePackageId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Object?> listCustomerAppointments() {
    return _request('GET', 'appointments');
  }

  @override
  Future<Map<String, dynamic>> createCustomerBooking(
    Map<String, dynamic> body,
  ) async {
    return _map(await _request('POST', 'appointments', body: body));
  }

  @override
  Future<Map<String, dynamic>> getCustomerAppointment(
    String appointmentId,
  ) async {
    return _map(
      await _request(
        'GET',
        'appointments/${Uri.encodeComponent(appointmentId)}',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> transitionCustomerAppointmentStatus({
    required String appointmentId,
    required Map<String, dynamic> body,
  }) async {
    return _map(
      await _request(
        'PATCH',
        'appointments/${Uri.encodeComponent(appointmentId)}/status',
        body: body,
      ),
    );
  }

  @override
  Future<Object?> getCustomerDashboardSummary() {
    return _request('GET', 'portal/dashboard/summary');
  }

  @override
  Future<Object?> listCustomerRepairOrders() {
    return _request('GET', 'repair-orders');
  }

  @override
  Future<Map<String, dynamic>> getCustomerRepairOrder(
    String repairOrderId,
  ) async {
    return _map(
      await _request(
        'GET',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}',
      ),
    );
  }

  @override
  Future<Object?> listCustomerRepairOrderTimeline(String repairOrderId) {
    return _request(
      'GET',
      'repair-orders/${Uri.encodeComponent(repairOrderId)}/timeline',
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerEstimate({
    required String repairOrderId,
    required String estimateId,
  }) async {
    return _map(
      await _request(
        'GET',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/estimates/'
            '${Uri.encodeComponent(estimateId)}',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> submitCustomerEstimateDecisions({
    required String repairOrderId,
    required String estimateId,
    required Map<String, dynamic> body,
  }) async {
    return _map(
      await _request(
        'POST',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/estimates/'
            '${Uri.encodeComponent(estimateId)}/decisions',
        body: body,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerInvoicePdfState(
    String invoiceId,
  ) async {
    return _map(
      await _request(
        'GET',
        'portal/invoices/${Uri.encodeComponent(invoiceId)}/pdf',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomerInvoicePdfDownloadUrl(
    String invoiceId, {
    String disposition = 'attachment',
  }) async {
    return _map(
      await _request(
        'POST',
        'portal/invoices/${Uri.encodeComponent(invoiceId)}/pdf/download-url',
        body: {'disposition': disposition},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerEstimatePdfState({
    required String repairOrderId,
    required String estimateId,
  }) async {
    return _map(
      await _request(
        'GET',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/estimates/'
            '${Uri.encodeComponent(estimateId)}/pdf',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomerEstimatePdfDownloadUrl({
    required String repairOrderId,
    required String estimateId,
    String disposition = 'attachment',
  }) async {
    return _map(
      await _request(
        'POST',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/estimates/'
            '${Uri.encodeComponent(estimateId)}/pdf/download-url',
        body: {'disposition': disposition},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerInspectionReportPdfState({
    required String repairOrderId,
    required String inspectionId,
  }) async {
    return _map(
      await _request(
        'GET',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/inspections/'
            '${Uri.encodeComponent(inspectionId)}/pdf',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomerInspectionReportPdfDownloadUrl({
    required String repairOrderId,
    required String inspectionId,
    String disposition = 'attachment',
  }) async {
    return _map(
      await _request(
        'POST',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/inspections/'
            '${Uri.encodeComponent(inspectionId)}/pdf/download-url',
        body: {'disposition': disposition},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerServiceHistoryPdfState(
    String repairOrderId,
  ) async {
    return _map(
      await _request(
        'GET',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}/service-history/pdf',
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomerServiceHistoryPdfDownloadUrl(
    String repairOrderId, {
    String disposition = 'attachment',
  }) async {
    return _map(
      await _request(
        'POST',
        'repair-orders/${Uri.encodeComponent(repairOrderId)}'
            '/service-history/pdf/download-url',
        body: {'disposition': disposition},
      ),
    );
  }

  @override
  Future<Object?> listCustomerInvoices({int? page, int? pageSize}) {
    return _request(
      'GET',
      'invoices',
      query: {'page': page?.toString(), 'pageSize': pageSize?.toString()},
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerInvoice(String invoiceId) async {
    return _map(
      await _request('GET', 'invoices/${Uri.encodeComponent(invoiceId)}'),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerPaymentRequest({
    required String tenantSlug,
    required String paymentRequestId,
    required String token,
  }) async {
    return _map(
      await _request(
        'GET',
        'payment-requests/${Uri.encodeComponent(paymentRequestId)}',
        auth: false,
        tenantSlug: tenantSlug,
        query: {'token': token},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCustomerFeedbackRequest({
    required String tenantSlug,
    required String token,
  }) async {
    return _map(
      await _request(
        'GET',
        'feedback/${Uri.encodeComponent(token)}',
        auth: false,
        tenantSlug: tenantSlug,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> submitCustomerFeedback({
    required String tenantSlug,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    return _map(
      await _request(
        'POST',
        'feedback/${Uri.encodeComponent(token)}',
        auth: false,
        tenantSlug: tenantSlug,
        body: body,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> submitTenantComplianceRequest(
    Map<String, dynamic> body,
  ) async {
    return _map(
      await _request('POST', 'compliance-requests', body: body, auth: false),
    );
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Map<String, dynamic>? body,
    bool auth = true,
    String? tenantSlug,
  }) async {
    final response = await _rawRequest(
      method,
      path,
      query: query,
      body: body,
      auth: auth,
      tenantSlug: tenantSlug,
    );

    if (response.body.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  Future<http.Response> _rawRequest(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Map<String, dynamic>? body,
    bool auth = true,
    String? tenantSlug,
    String accept = 'application/json',
  }) async {
    final request = http.Request(
      method,
      config.tenantUri(path, tenantSlugOverride: tenantSlug, query: query),
    );
    request.headers['Accept'] = accept;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    if (auth) {
      final cookie = await _readSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        request.headers['Cookie'] = cookie;
      }
    }

    final response = await _send(request);
    final cookie = extractCustomerSessionCookie(response.headers);
    if (cookie != null) {
      await _writeSessionCookie(cookie);
    }

    if (response.statusCode == 401) {
      await _clearSessionCookie();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MotornautsApiException.fromResponse(
        response.statusCode,
        response.body,
      );
    }

    return response;
  }

  Future<String?> _readSessionCookie() async {
    try {
      final cookie = await _sessionStore.readCookie();
      if (cookie != null && cookie.isNotEmpty) {
        _sessionCookieFallback = cookie;
      }
      return cookie ?? _sessionCookieFallback;
    } catch (_) {
      return _sessionCookieFallback;
    }
  }

  Future<void> _writeSessionCookie(String cookie) async {
    _sessionCookieFallback = cookie;
    try {
      await _sessionStore.writeCookie(cookie);
    } catch (_) {
      return;
    }
  }

  Future<void> _clearSessionCookie() async {
    _sessionCookieFallback = null;
    try {
      await _sessionStore.clearCookie();
    } catch (_) {
      return;
    }
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _httpClient.send(request).timeout(config.timeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const MotornautsNetworkException('Network timeout. Please retry.');
    } on http.ClientException {
      throw const MotornautsNetworkException('Network request failed.');
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map) {
      return data.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return const {};
  }
}
