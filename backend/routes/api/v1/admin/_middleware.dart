import 'package:backend/api/v1/admin/repository/admin_repository.dart';
import 'package:backend/api/v1/admin/service/admin_service.dart';
import 'package:backend/core/database/database.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(adminServiceProvider()).use(adminRepositoryProvider());
}

Middleware adminRepositoryProvider() {
  return provider<AdminRepository>(
    (context) => AdminRepository(
      databaseClient: context.read<DatabaseClient>(),
    ),
  );
}

Middleware adminServiceProvider() {
  return provider<AdminService>(
    (context) => AdminService(
      adminRepository: context.read<AdminRepository>(),
    ),
  );
}
