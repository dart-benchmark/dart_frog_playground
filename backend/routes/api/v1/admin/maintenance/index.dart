import 'dart:io';

import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  return _runMaintenance(context);
}

// Ops maintenance runner: an operator kicks off one of the routine cluster
// utilities (compaction, index rebuild, replica resync, ...) by name while
// working a ticket, so nobody needs shell access to the box just to start a
// standard maintenance job. The tool set ships in the ops toolchain image.
Future<Response> _runMaintenance(RequestContext context) async {
  final adminService = context.read<AdminService>();
  final body = await context.request.json() as Map<String, dynamic>;

  //CWE-78
  //SOURCE
  final toolName = body['tool'] as String? ?? 'mongo-compact';
  final arguments = (body['args'] as List?)?.cast<String>() ?? const <String>[];

  final result = await adminService.runMaintenanceTask(toolName, arguments);
  return result.fold(
    (error) => Response.json(
      statusCode: HttpStatus.internalServerError,
      body: error.toJson(),
    ),
    (exitCode) => Response.json(body: {'tool': toolName, 'exitCode': exitCode}),
  );
}
