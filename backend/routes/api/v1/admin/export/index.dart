import 'dart:io';

import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  return _exportDataset(context);
}

// Data export: lets an operator dump a whole dataset (compliance ledger,
// tenant orders, ...) as JSON, e.g. to hand to an auditor -- so operators
// never have to change code every time compliance asks for a new export.
Future<Response> _exportDataset(RequestContext context) async {
  final adminService = context.read<AdminService>();
  final body = await context.request.json() as Map<String, dynamic>;

  final datasetKey = body['datasetKey'] as String? ?? '';
  final apiVersion = body['apiVersion'] as int? ?? 1;

  final exportResponse = await adminService.exportDataset(
    datasetKey,
    useApprovedCatalog: apiVersion >= 2,
  );
  return exportResponse.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    (entries) => Response.json(body: {'entries': entries}),
  );
}
