import 'dart:io';
import 'package:backend/core/database/database.dart';
import 'package:backend/core/utils/admin_bootstrap.dart';
import 'package:backend/core/utils/service_registry.dart';
import 'package:dart_frog/dart_frog.dart';

final DatabaseClient _databaseClient = DatabaseClient.instance;

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  await _databaseClient.connect();
  await AdminBootstrap.ensureDefaultAdminAccount(_databaseClient);
  await ServiceRegistry.registerInstance();
  return serve(handler.use(databaseProvider()).use(requestLogger()), ip, port);
}

Middleware databaseProvider() {
  return provider<DatabaseClient>((_) => _databaseClient);
}
