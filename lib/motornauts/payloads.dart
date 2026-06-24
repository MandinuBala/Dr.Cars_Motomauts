class MotornautsPayloads {
  const MotornautsPayloads._();

  static Map<String, dynamic> otpRequest({
    required String channel,
    String? email,
    String? phone,
  }) {
    return _compact({'channel': channel, 'email': email, 'phone': phone});
  }

  static Map<String, dynamic> selfRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    required String registrationNumber,
    required String vehicleType,
    required String make,
    required String model,
    required int year,
    required String fuelType,
    required String transmission,
    required int currentMileage,
    String? chassisNumber,
    String? engineNumber,
    String? nickname,
    String? ownershipStatus,
    required bool termsAccepted,
    bool marketingConsent = false,
  }) {
    return _compact({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'registrationNumber': registrationNumber,
      'vehicleType': vehicleType,
      'make': make,
      'model': model,
      'year': year,
      'fuelType': fuelType,
      'transmission': transmission,
      'currentMileage': currentMileage,
      'chassisNumber': chassisNumber,
      'engineNumber': engineNumber,
      'nickname': nickname,
      'ownershipStatus': ownershipStatus,
      'termsAccepted': termsAccepted,
      'marketingConsent': marketingConsent,
    });
  }

  static Map<String, dynamic> profileUpdate({
    String? firstName,
    String? lastName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
  }) {
    return _compact({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
    });
  }

  static Map<String, dynamic> vehicle({
    String? tenantCustomerId,
    required String registrationNumber,
    required String vehicleType,
    required String make,
    required String model,
    required int year,
    required String fuelType,
    required String transmission,
    required int currentMileage,
    String? chassisNumber,
    String? engineNumber,
    String? nickname,
    String? ownershipStatus,
  }) {
    return _compact({
      'tenantCustomerId': tenantCustomerId,
      'registrationNumber': registrationNumber,
      'vehicleType': vehicleType,
      'make': make,
      'model': model,
      'year': year,
      'fuelType': fuelType,
      'transmission': transmission,
      'currentMileage': currentMileage,
      'chassisNumber': chassisNumber,
      'engineNumber': engineNumber,
      'nickname': nickname,
      'ownershipStatus': ownershipStatus,
    });
  }

  static Map<String, dynamic> documentUploadIntent({
    required String documentType,
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    String? checksumSha256,
  }) {
    return _compact({
      'documentType': documentType,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'checksumSha256': checksumSha256,
    });
  }

  static Map<String, dynamic> booking({
    required String vehicleId,
    required String branchId,
    required String servicePackageId,
    required DateTime requestedStartAt,
    DateTime? requestedEndAt,
    int? mileageAtBooking,
    String? customerNotes,
    String? complaints,
    required String idempotencyKey,
  }) {
    return _compact({
      'vehicleId': vehicleId,
      'branchId': branchId,
      'servicePackageId': servicePackageId,
      'requestedStartAt': requestedStartAt.toUtc().toIso8601String(),
      'requestedEndAt': requestedEndAt?.toUtc().toIso8601String(),
      'mileageAtBooking': mileageAtBooking,
      'customerNotes': customerNotes,
      'complaints': complaints,
      'idempotencyKey': idempotencyKey,
    });
  }

  static Map<String, dynamic> estimateDecisionBatch({
    required int estimateVersion,
    required String idempotencyKey,
    required List<Map<String, dynamic>> decisions,
  }) {
    return {
      'estimateVersion': estimateVersion,
      'idempotencyKey': idempotencyKey,
      'decisions': decisions,
    };
  }

  static Map<String, dynamic> feedback({required int rating, String? comment}) {
    return _compact({'rating': rating, 'comment': comment});
  }

  static Map<String, dynamic> complianceRequest({
    required String requestType,
    String? requesterType,
    String? requesterName,
    String? requesterEmail,
    String? requesterPhone,
    required String summary,
    required Map<String, dynamic> evidence,
    required String sourceEntityType,
    String? sourceEntityId,
    String? turnstileToken,
  }) {
    return _compact({
      'requestType': requestType,
      'requesterType': requesterType ?? 'CUSTOMER',
      'requesterName': requesterName,
      'requesterEmail': requesterEmail,
      'requesterPhone': requesterPhone,
      'summary': summary,
      'evidence': evidence,
      'sourceEntityType': sourceEntityType,
      'sourceEntityId': sourceEntityId,
      'turnstileToken': turnstileToken,
    });
  }

  static Map<String, dynamic> _compact(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    for (final entry in input.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      output[entry.key] = value;
    }
    return output;
  }
}
