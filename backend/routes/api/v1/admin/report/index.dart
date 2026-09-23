import 'dart:io';

import 'package:backend/api/v1/admin/model/report_request.dart';
import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  return _generateReport(context);
}

// Report generation: an internal reporting tool names its target collection
// via a request header (rather than a body field, since this endpoint takes
// no body) -- the header is captured here and carried down to the repository
// on a small request object, read back out one layer below.
Future<Response> _generateReport(RequestContext context) async {
  final adminService = context.read<AdminService>();

  final targetCollection = context.request.headers['X-Report-Collection'] ?? '';
  final apiVersion = int.tryParse(context.request.uri.queryParameters['apiVersion'] ?? '') ?? 1;
  final request = ReportRequest(targetCollection: targetCollection);

  final reportResponse = await adminService.generateReport(
    request,
    useApprovedCatalog: apiVersion >= 2,
  );
  return reportResponse.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    (entries) => Response.json(body: {'entries': entries}),
  );
}
