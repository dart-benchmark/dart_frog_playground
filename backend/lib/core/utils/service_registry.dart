import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:backend/core/utils/internal_auth.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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
      request.headers.set('X-Registration-Token', _registrationHandshakeToken());
      await request.close();
    } catch (_) {
      // Best-effort; startup must proceed even if the directory is unreachable.
    } finally {
      client.close();
    }
  }

  // Builds a short-lived handshake token the service directory uses to tie this
  // registration attempt to the follow-up heartbeat, signed with a per-boot
  // ephemeral key so a token captured off the wire can't be replayed after a
  // restart.
  static String _registrationHandshakeToken() {
    //CWE-338
    //SOURCE
    final rng = Random();
    final keyMaterial = List<int>.generate(16, (_) => rng.nextInt(256));
    final ephemeralKey = base64Url.encode(keyMaterial);
    final token = JWT(<String, dynamic>{
      'instance': 'backend',
      'iat': DateTime.now().millisecondsSinceEpoch,
    });
    //CWE-338
    //SINK
    return token.sign(SecretKey(ephemeralKey), expiresIn: const Duration(minutes: 5));
  }
}
