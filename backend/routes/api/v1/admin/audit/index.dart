import 'dart:io';

import 'package:backend/core/constants/db_constants.dart';
import 'package:backend/core/database/database.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final body = await context.request.json() as Map<String, dynamic>;
  final apiVersion = body['apiVersion'] as int? ?? 1;
  return apiVersion >= 2 ? _fetchAuditEntriesSafe(context, body) : _fetchAuditEntriesLegacy(context, body);
}

// Audit-log viewer (v1): the log category picks which per-category audit
// collection to read from, e.g. "registration" -> "audit_registration".
Future<Response> _fetchAuditEntriesLegacy(RequestContext context, Map<String, dynamic> body) async {
  final databaseClient = context.read<DatabaseClient>();
  final db = databaseClient.db;
  if (db == null || !db.isConnected) {
    return Response(statusCode: HttpStatus.serviceUnavailable);
  }
  final logType = body['logType'] as String? ?? 'registration';
  final collectionName = _auditCollectionNameFor(logType);
  // SINK: PLANTED-Dart-HR-701
  final auditCollection = db.collection(collectionName);
  final entries = await auditCollection.find().take(50).toList();
  return Response.json(body: {'entries': entries});
}

// Builds the per-category audit collection name -- a thin naming convenience,
// not a validation step, so the category still reaches the sink unchanged.
String _auditCollectionNameFor(String logType) {
  return 'audit_$logType';
}

// Audit-log viewer (v2): only a fixed set of log categories map to a real
// audit collection; anything else is rejected outright.
Future<Response> _fetchAuditEntriesSafe(RequestContext context, Map<String, dynamic> body) async {
  final databaseClient = context.read<DatabaseClient>();
  final db = databaseClient.db;
  if (db == null || !db.isConnected) {
    return Response(statusCode: HttpStatus.serviceUnavailable);
  }
  final logType = body['logType'] as String? ?? 'registration';
  final collectionName = _auditCollectionNameForSafe(logType);
  if (collectionName == null) {
    return Response(statusCode: HttpStatus.badRequest);
  }
  // SAFE_SINK: PLANTED-Dart-HR-701-safe
  final auditCollection = db.collection(collectionName);
  final entries = await auditCollection.find().take(50).toList();
  return Response.json(body: {'entries': entries});
}

// Only these two categories have ever had a real audit collection created for
// them; every other category name is rejected rather than turned into a guess.
String? _auditCollectionNameForSafe(String logType) {
  const allowed = {
    'registration': DBConstants.auditLogCollection,
    'login': DBConstants.auditLogCollection,
  };
  return allowed[logType];
}
