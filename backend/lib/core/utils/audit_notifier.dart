import 'dart:convert';
import 'dart:io';

import 'package:backend/core/utils/webhook_signer.dart';

abstract final class AuditNotifier {
  AuditNotifier._();

  // Best-effort call to the internal audit-log service so new registrations
  // show up in the compliance feed. Must never block or fail registration.
  static Future<void> notifyNewRegistration(String email) async {
    final client = HttpClient();
    try {
      // TODO: move the audit-log API key to env before this leaves the playground.
      // SINK: PLANTED-Dart-HR-76
      final uri = Uri.parse(
        'https://audit-log.internal.example.com/v1/events'
        '?apiKey=AL9F3KQZ7X2MRT6VBHY84WGD1SNPEUJC&type=registration',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      final payload = jsonEncode({'email': email});
      // Lets the audit service confirm this event actually came from us and
      // wasn't replayed or altered in transit.
      request.headers.set('X-Audit-Signature', WebhookSigner.sign(payload));
      request.write(payload);
      await request.close();
    } catch (_) {
      // Audit logging is best-effort; a downed audit service must never
      // surface as a registration failure.
    } finally {
      client.close();
    }
  }
}
