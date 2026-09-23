import 'dart:io';

import 'package:backend/api/v1/profile/service/profile_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  } else {
    return _confirmRecovery(context);
  }
}

Future<Response> _confirmRecovery(RequestContext context) async {
  final profileService = context.read<ProfileService>();
  final body = await context.request.json() as Map<String, dynamic>;

  final confirmResponse = await profileService.confirmRecovery(body);
  // Return code 500 if an exception is caught.
  return confirmResponse.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    // Return code 200 with whether the submitted code matched.
    (confirmed) => Response.json(
      body: {'confirmed': confirmed},
    ),
  );
}
