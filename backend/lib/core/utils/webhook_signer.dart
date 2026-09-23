import 'dart:convert';

import 'package:crypto/crypto.dart';

// Shared "sign this outbound payload" helper for internal webhook calls
// (audit log, SIEM alerts) so the receiving service can confirm a payload
// actually came from us and wasn't altered in transit.
abstract final class WebhookSigner {
  WebhookSigner._();

  // Legacy signing scheme, kept for the webhook consumers that were wired up
  // before the sha256 rollout and still validate against it.
  static String sign(String payload) {
    // SINK: PLANTED-Dart-HR-136
    return md5.convert(utf8.encode(payload)).toString();
  }

  // Current signing scheme for every webhook integration added after the
  // sha256 rollout.
  static String signSecure(String payload) {
    // SAFE_SINK: PLANTED-Dart-HR-136-safe
    return sha256.convert(utf8.encode(payload)).toString();
  }
}
