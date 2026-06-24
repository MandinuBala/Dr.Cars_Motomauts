enum MotornautsLinkType { payment, feedback }

class ParsedMotornautsLink {
  const ParsedMotornautsLink.payment({
    required this.tenantSlug,
    required this.paymentRequestId,
    required this.token,
  }) : type = MotornautsLinkType.payment,
       feedbackToken = null;

  const ParsedMotornautsLink.feedback({
    required this.tenantSlug,
    required this.feedbackToken,
  }) : type = MotornautsLinkType.feedback,
       paymentRequestId = null,
       token = null;

  final MotornautsLinkType type;
  final String tenantSlug;
  final String? paymentRequestId;
  final String? token;
  final String? feedbackToken;
}

ParsedMotornautsLink? parseMotornautsLink(Uri uri) {
  if (uri.scheme == 'motornauts') {
    return _parseCustomScheme(uri);
  }

  final segments = uri.pathSegments;
  if (segments.length >= 4 && segments[0] == 't') {
    final tenantSlug = segments[1];
    if (segments[2] == 'payment-requests') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        return ParsedMotornautsLink.payment(
          tenantSlug: tenantSlug,
          paymentRequestId: segments[3],
          token: token,
        );
      }
    }
    if (segments[2] == 'feedback') {
      return ParsedMotornautsLink.feedback(
        tenantSlug: tenantSlug,
        feedbackToken: segments[3],
      );
    }
  }

  return null;
}

ParsedMotornautsLink? _parseCustomScheme(Uri uri) {
  final tenantSlug = uri.queryParameters['tenantSlug'];
  if (tenantSlug == null || tenantSlug.isEmpty) {
    return null;
  }

  if (uri.host == 'payment') {
    final paymentRequestId =
        uri.queryParameters['paymentRequestId'] ??
        (uri.pathSegments.isEmpty ? null : uri.pathSegments.last);
    final token = uri.queryParameters['token'];
    if (paymentRequestId != null &&
        paymentRequestId.isNotEmpty &&
        token != null &&
        token.isNotEmpty) {
      return ParsedMotornautsLink.payment(
        tenantSlug: tenantSlug,
        paymentRequestId: paymentRequestId,
        token: token,
      );
    }
  }

  if (uri.host == 'feedback') {
    final token =
        uri.queryParameters['token'] ??
        (uri.pathSegments.isEmpty ? null : uri.pathSegments.last);
    if (token != null && token.isNotEmpty) {
      return ParsedMotornautsLink.feedback(
        tenantSlug: tenantSlug,
        feedbackToken: token,
      );
    }
  }

  return null;
}
