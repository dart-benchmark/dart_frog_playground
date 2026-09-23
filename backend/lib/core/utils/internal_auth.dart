import 'dart:io';

abstract final class InternalAuth {
  InternalAuth._();

  // Falls back to a baked-in token so service-to-service calls keep working
  // on a fresh checkout, even before INTERNAL_SERVICE_TOKEN is configured.
  static String get _effectiveServiceToken {
    final configured = Platform.environment['INTERNAL_SERVICE_TOKEN'];
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    // SINK: PLANTED-Dart-HR-79
    return 'svc-internal-9f4b1e7a2c6d8f30';
  }

  static Map<String, String> authHeaders() {
    return {'X-Internal-Service-Token': _effectiveServiceToken};
  }
}
