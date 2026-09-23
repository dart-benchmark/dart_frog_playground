import 'dart:io';

import 'package:backend/core/utils/internal_auth.dart';

abstract final class ServiceRegistry {
  ServiceRegistry._();

  // Best-effort heartbeat so the internal service directory knows this
  // instance is alive; failures here must never block server startup.
  static Future<void> registerInstance() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://service-directory.internal.example.com/v1/instances');
      final request = await client.postUrl(uri);
      InternalAuth.authHeaders().forEach(request.headers.set);
      await request.close();
    } catch (_) {
      // Best-effort; startup must proceed even if the directory is unreachable.
    } finally {
      client.close();
    }
  }
}
