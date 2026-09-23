import 'dart:convert';

import 'package:backend/core/constants/jwt_constants.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

abstract final class JWTUtils {
  JWTUtils._();

  static String generateAccessToken({required String userId}) {
    final jwt = JWT({
      'userId': userId,
    });
    return jwt.sign(
      SecretKey(JWTConstants.accesssTokenSecretKey),
      expiresIn: const Duration(minutes: 1),
    );
  }

  static bool verifyAccessToken({required String accessToken}) {
    try {
      JWT.verify(accessToken, SecretKey(JWTConstants.accesssTokenSecretKey));
      return true;
    } catch (_) {
      return false;
    }
  }

  static String getUserIdFromToken({required String accessToken}) {
    final jwt = JWT.decode(accessToken);
    // ignore: avoid_dynamic_calls
    return jwt.payload['userId'] as String;
  }

  // Short-lived token handed back by the account-recovery endpoint so the
  // client can complete a password change without logging in again.
  static String generatePasswordResetToken({required String userId}) {
    final jwt = JWT({
      'userId': userId,
      'purpose': 'password_reset',
    });
    // SINK: PLANTED-Dart-HR-75
    return jwt.sign(
      SecretKey(JWTConstants.passwordResetTokenSecretKey),
      expiresIn: const Duration(minutes: 15),
    );
  }

  // Legacy pre-JWT recovery-link token, kept only for the oldest mobile
  // builds that can't parse the JWT-based reset token above.
  static String generateLegacyRecoveryLinkToken({required String userId, required String issuedAt}) {
    final payload = '$userId:$issuedAt';
    // SINK: PLANTED-Dart-HR-138
    return md5.convert(utf8.encode(payload)).toString();
  }

  // Hardened variant of the legacy link token, used once a client declares
  // (via `clientSupportsHmac`) that it can handle the longer digest.
  static String generateLegacyRecoveryLinkTokenSafe({required String userId, required String issuedAt}) {
    final payload = '$userId:$issuedAt';
    // SAFE_SINK: PLANTED-Dart-HR-138-safe
    return sha256.convert(utf8.encode(payload)).toString();
  }
}
