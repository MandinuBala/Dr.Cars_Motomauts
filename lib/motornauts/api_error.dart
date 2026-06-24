import 'dart:convert';

enum MotornautsErrorType {
  unauthenticated,
  forbidden,
  notFound,
  validationProblem,
  rateLimited,
  serverError,
  networkError,
  unknown,
}

class MotornautsApiException implements Exception {
  MotornautsApiException({
    required this.type,
    required this.statusCode,
    required this.message,
    this.error,
    this.messageKey,
    this.details,
    this.requestId,
  });

  factory MotornautsApiException.fromResponse(int statusCode, String body) {
    Map<String, dynamic> decoded = const {};
    if (body.isNotEmpty) {
      try {
        final value = jsonDecode(body);
        if (value is Map) {
          decoded = Map<String, dynamic>.from(value);
        }
      } catch (_) {
        decoded = const {};
      }
    }

    final error = decoded['error']?.toString();
    final details = decoded['details'];
    return MotornautsApiException(
      type: _typeFor(statusCode, error),
      statusCode: statusCode,
      error: error,
      message:
          decoded['message']?.toString() ??
          (body.isEmpty ? 'Request failed.' : body),
      messageKey: decoded['messageKey']?.toString(),
      details: details is Map ? Map<String, dynamic>.from(details) : null,
      requestId: decoded['requestId']?.toString(),
    );
  }

  final MotornautsErrorType type;
  final int statusCode;
  final String? error;
  final String message;
  final String? messageKey;
  final Map<String, dynamic>? details;
  final String? requestId;

  Map<String, String> get fieldMessages {
    final source = details;
    if (source == null) {
      return const {};
    }

    final output = <String, String>{};
    void addValue(String key, Object? value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        output[key] = value.map((item) => item.toString()).join(', ');
      } else {
        output[key] = value.toString();
      }
    }

    final fieldErrors = source['fieldErrors'];
    if (fieldErrors is Map) {
      for (final entry in fieldErrors.entries) {
        addValue(entry.key.toString(), entry.value);
      }
    }

    final errors = source['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        addValue(entry.key.toString(), entry.value);
      }
    }

    for (final entry in source.entries) {
      if (entry.value is String || entry.value is Iterable) {
        addValue(entry.key, entry.value);
      }
    }

    return output;
  }

  @override
  String toString() => message;

  static MotornautsErrorType _typeFor(int statusCode, String? error) {
    if (statusCode == 401) {
      return MotornautsErrorType.unauthenticated;
    }
    if (statusCode == 403) {
      return MotornautsErrorType.forbidden;
    }
    if (statusCode == 404) {
      return MotornautsErrorType.notFound;
    }
    if (statusCode == 400 ||
        statusCode == 422 ||
        error == 'validation_problem') {
      return MotornautsErrorType.validationProblem;
    }
    if (statusCode == 429) {
      return MotornautsErrorType.rateLimited;
    }
    if (statusCode >= 500) {
      return MotornautsErrorType.serverError;
    }
    return MotornautsErrorType.unknown;
  }
}

class MotornautsNetworkException implements Exception {
  const MotornautsNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SignedUploadException implements Exception {
  const SignedUploadException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'Signed upload failed with status $statusCode.';
}
