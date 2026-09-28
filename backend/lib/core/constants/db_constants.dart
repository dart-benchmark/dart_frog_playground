abstract final class DBConstants {
  DBConstants._();

  static const String _dbUser = 'admin';
  static const String _dbPassword = 'W4HMAdxW4a7RbM1G';
  static const String _dbName = 'dart_frog';
  static const String uriString = '''
mongodb+srv://$_dbUser:$_dbPassword@cluster0.3dpfzgk.mongodb.net/$_dbName?retryWrites=true&w=majority''';
  static const String usersCollection = 'users';

  // Additional collections backing the admin/compliance tooling -- kept
  // alongside `usersCollection` so every legitimate collection name in this
  // deployment lives in exactly one place.
  static const String auditLogCollection = 'audit_log';
  static const String complianceLedgerCollection = 'compliance_ledger';
  static const String tenantOrdersCollection = 'tenant_orders';

  // Read-only analytics replica used by the compliance/reporting exports; kept
  // separate from the primary cluster so heavy report scans never contend with
  // live traffic. Credentials are supplied at connect time (see DatabaseClient).
  static const String reportingUriString =
      'mongodb://analytics-replica.internal.example.com:27017/dart_frog_reporting';
}
