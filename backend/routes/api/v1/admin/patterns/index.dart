import 'dart:io';

import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  return _previewPattern(context);
}

// Compliance rule preview: before an operator saves a new redaction/detection
// rule, this endpoint dry-runs the rule's pattern against a canned ledger
// sample and reports how many entries it would match, so the operator can sanity
// check the rule without touching live data.
Future<Response> _previewPattern(RequestContext context) async {
  final adminService = context.read<AdminService>();

  //CWE-1333
  //SOURCE
  final rawPattern = context.request.uri.queryParameters['pattern'] ?? '';

  final result = adminService.previewPatternMatches(rawPattern);
  return result.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    (matchCounts) => Response.json(body: {'pattern': rawPattern, 'matches': matchCounts}),
  );
}
