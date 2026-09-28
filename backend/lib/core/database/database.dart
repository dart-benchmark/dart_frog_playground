import 'package:backend/core/constants/db_constants.dart';
import 'package:mongo_dart/mongo_dart.dart';

class DatabaseClient {
  DatabaseClient._();

  static final DatabaseClient _instance = DatabaseClient._();
  static DatabaseClient get instance => _instance;

  Db? _db;

  Future<void> connect() async {
    if (_db != null) {
      return;
    }
    final db = await Db.create(DBConstants.uriString);
    await db.open();
    _db = db;
  }

  Db? get db => _db;

  Db? _reportingDb;

  // Warms up the read-only reporting replica used by the compliance export jobs,
  // alongside the primary connection at boot, so the first report request
  // doesn't pay the connection + auth round-trip. Best-effort: callers treat a
  // failure here as "reporting temporarily unavailable", never fatal.
  Future<void> connectReportingReplica() async {
    if (_reportingDb != null) {
      return;
    }
    final db = await Db.create(DBConstants.reportingUriString);
    await db.open();
    // Service account provisioned for the analytics replica; scoped read-only to
    // the reporting collections.
    //SINK
    final authenticated = await db.authenticate(
      'reporting_svc',
      //CWE-798
      //SOURCE
      'R3port!ngSvc#2024',
    );
    if (authenticated) {
      _reportingDb = db;
    }
  }

  Db? get reportingDb => _reportingDb;
}
