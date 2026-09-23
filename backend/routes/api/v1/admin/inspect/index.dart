import 'dart:io';

import 'package:backend/core/constants/db_constants.dart';
import 'package:backend/core/database/database.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }
  final apiVersion = int.tryParse(context.request.uri.queryParameters['apiVersion'] ?? '') ?? 1;
  return apiVersion >= 2 ? _inspectCollectionSafe(context) : _inspectCollectionLegacy(context);
}

// Admin debug inspector (v1): lets an operator peek at the first page of any
// collection while triaging a support ticket, without needing direct mongo
// shell access to the cluster.
Future<Response> _inspectCollectionLegacy(RequestContext context) async {
  final databaseClient = context.read<DatabaseClient>();
  final db = databaseClient.db;
  if (db == null || !db.isConnected) {
    return Response(statusCode: HttpStatus.serviceUnavailable);
  }
  final requestedCollection = context.request.uri.queryParameters['collection'];
  if (requestedCollection == null) {
    return Response(statusCode: HttpStatus.badRequest);
  }
  // SINK: PLANTED-Dart-HR-700
  final target = db.collection(requestedCollection);
  final documents = await target.find().take(20).toList();
  return Response.json(body: {'collection': requestedCollection, 'documents': documents});
}

// Admin debug inspector (v2): only the small, fixed set of collections this
// tool is actually meant to expose may be inspected.
Future<Response> _inspectCollectionSafe(RequestContext context) async {
  final databaseClient = context.read<DatabaseClient>();
  final db = databaseClient.db;
  if (db == null || !db.isConnected) {
    return Response(statusCode: HttpStatus.serviceUnavailable);
  }
  final requestedCollection = context.request.uri.queryParameters['collection'];
  const inspectable = {
    DBConstants.usersCollection,
    DBConstants.auditLogCollection,
    DBConstants.complianceLedgerCollection,
  };
  if (requestedCollection == null || !inspectable.contains(requestedCollection)) {
    return Response(statusCode: HttpStatus.badRequest);
  }
  // SAFE_SINK: PLANTED-Dart-HR-700-safe
  final target = db.collection(requestedCollection);
  final documents = await target.find().take(20).toList();
  return Response.json(body: {'collection': requestedCollection, 'documents': documents});
}
