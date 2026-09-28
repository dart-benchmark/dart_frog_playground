import 'dart:io';
import 'package:backend/core/database/database.dart';
import 'package:backend/core/utils/admin_bootstrap.dart';
import 'package:backend/core/utils/service_registry.dart';
import 'package:dart_frog/dart_frog.dart';

final DatabaseClient _databaseClient = DatabaseClient.instance;

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  await _databaseClient.connect();
  await AdminBootstrap.ensureDefaultAdminAccount(_databaseClient);
  try {
    await _databaseClient.connectReportingReplica();
  } catch (_) {
    // Reporting replica is optional; the primary path must still come up.
  }
  await ServiceRegistry.registerInstance();
  return serve(handler.use(databaseProvider()).use(requestLogger()), ip, port);
}

Middleware databaseProvider() {
  return provider<DatabaseClient>((_) => _databaseClient);
}
