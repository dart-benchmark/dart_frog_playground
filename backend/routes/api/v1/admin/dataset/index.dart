import 'dart:io';

import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  return _fetchDataset(context);
}

// Dataset lookup: newer clients send a structured `{"category": "..."}`
// selector; a handful of older internal scripts, predating the catalog
// rollout, still send the target Mongo collection name directly as a bare
// string -- both are accepted here for backward compatibility.
Future<Response> _fetchDataset(RequestContext context) async {
  final adminService = context.read<AdminService>();
  final body = await context.request.json() as Map<String, dynamic>;

  final target = body['target'];
  final datasetResponse = await adminService.fetchByTarget(target);
  return datasetResponse.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    (entries) => Response.json(body: {'entries': entries}),
  );
}
