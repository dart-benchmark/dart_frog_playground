import 'dart:io';

import 'package:backend/api/v1/profile/service/profile_service.dart';
import 'package:backend/core/utils/jwt_utils.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  } else {
    return _recoverAccount(context);
  }
}

Future<Response> _recoverAccount(RequestContext context) async {
  final profileService = context.read<ProfileService>();
  final body = await context.request.json() as Map<String, dynamic>;

  final recoveryResponse = await profileService.recoverAccount(body);
  // Return code 500 if an exception is caught.
  return recoveryResponse.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    // Return code 200, user information plus a short-lived password-reset
    // token if a matching account was found.
    (success) => Response.json(
      body: {
        ...success.toJson(),
        'resetToken': JWTUtils.generatePasswordResetToken(userId: success.userId),
        // Kept alongside the JWT reset token above for clients too old to
        // parse a JWT; `clientSupportsHmac` lets a client opt into the
        // hardened digest once it's been updated to verify it.
        'legacyRecoveryToken': (body['clientSupportsHmac'] as bool? ?? false)
            ? JWTUtils.generateLegacyRecoveryLinkTokenSafe(
                userId: success.userId,
                issuedAt: DateTime.now().toIso8601String(),
              )
            : JWTUtils.generateLegacyRecoveryLinkToken(
                userId: success.userId,
                issuedAt: DateTime.now().toIso8601String(),
              ),
      },
    ),
  );
}
