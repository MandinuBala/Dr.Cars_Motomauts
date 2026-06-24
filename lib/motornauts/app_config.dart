class MotornautsConfig {
  MotornautsConfig({
    required String apiBaseUrl,
    required this.tenantSlug,
    this.requestTimeoutSeconds = 30,
    this.enableSseTimeline = false,
    this.enablePaymentCustomTab = true,
  }) : apiBaseUrl = _withoutTrailingSlashes(apiBaseUrl);

  factory MotornautsConfig.fromEnvironment() {
    return MotornautsConfig(
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.motornauts.com',
      ),
      tenantSlug: const String.fromEnvironment(
        'TENANT_SLUG',
        defaultValue: 'anton-auto-care',
      ),
      requestTimeoutSeconds: const int.fromEnvironment(
        'REQUEST_TIMEOUT_SECONDS',
        defaultValue: 30,
      ),
      enableSseTimeline: const bool.fromEnvironment('ENABLE_SSE_TIMELINE'),
      enablePaymentCustomTab: const bool.fromEnvironment(
        'ENABLE_PAYMENT_CUSTOM_TAB',
        defaultValue: true,
      ),
    );
  }

  final String apiBaseUrl;
  final String tenantSlug;
  final int requestTimeoutSeconds;
  final bool enableSseTimeline;
  final bool enablePaymentCustomTab;

  Duration get timeout => Duration(seconds: requestTimeoutSeconds);

  Uri tenantUri(
    String path, {
    String? tenantSlugOverride,
    Map<String, String?> query = const {},
  }) {
    final tenant = Uri.encodeComponent(tenantSlugOverride ?? tenantSlug);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$apiBaseUrl/t/$tenant/$cleanPath');
    final cleanQuery = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        cleanQuery[entry.key] = value;
      }
    }
    return cleanQuery.isEmpty ? uri : uri.replace(queryParameters: cleanQuery);
  }

  static String _withoutTrailingSlashes(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
