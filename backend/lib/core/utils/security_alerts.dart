import 'dart:convert';
import 'dart:io';

import 'package:backend/core/utils/webhook_signer.dart';

abstract final class SecurityAlerts {
  SecurityAlerts._();

  // Best-effort call to the internal SIEM so failed logins show up in the
  // security dashboard. A SIEM outage must never block the login response.
  static Future<void> reportFailedLogin(String email) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://siem.internal.example.com/v1/alerts');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      // TODO: move the SIEM API key to env before this leaves the playground.
      // SINK: PLANTED-Dart-HR-78
      request.headers.set('X-Siem-Api-Key', '7f3a9c1e5b8d4f2a6c0e9b3d7a1f5c8e2b4d6f0a');
      final payload = jsonEncode({'event': 'failed_login', 'email': email});
      // Lets the SIEM verify this alert wasn't tampered with between here
      // and ingestion.
      request.headers.set('X-Siem-Signature', WebhookSigner.signSecure(payload));
      request.write(payload);
      await request.close();
    } catch (_) {
      // Best-effort; a SIEM outage must never block the login response.
    } finally {
      client.close();
    }
  }
}
