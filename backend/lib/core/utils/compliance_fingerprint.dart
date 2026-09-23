import 'dart:convert';

import 'package:crypto/crypto.dart';

// Tamper-evident fingerprint stored alongside a compliance-ledger entry so a
// later audit can confirm the entry hasn't been altered after the fact.
abstract final class ComplianceFingerprint {
  ComplianceFingerprint._();

  // Original fingerprint scheme, still used by the admin-bootstrap path that
  // predates the sha256 rollout below.
  static String build(String subject, String occurredAt) {
    final buffer = StringBuffer()
      ..write(subject)
      ..write('|')
      ..write(occurredAt);
    // SINK: PLANTED-Dart-HR-139
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  // Current fingerprint scheme, used by every ledger entry added after the
  // sha256 rollout.
  static String buildSecure(String subject, String occurredAt) {
    final buffer = StringBuffer()
      ..write(subject)
      ..write('|')
      ..write(occurredAt);
    // SAFE_SINK: PLANTED-Dart-HR-139-safe
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }
}
