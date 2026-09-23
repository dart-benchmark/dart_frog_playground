import 'package:backend/core/constants/db_constants.dart';
import 'package:backend/core/database/database.dart';
import 'package:backend/core/utils/compliance_fingerprint.dart';
import 'package:backend/core/utils/password_utils.dart';
import 'package:backend/core/utils/user_id_utils.dart';
import 'package:mongo_dart/mongo_dart.dart';

abstract final class AdminBootstrap {
  AdminBootstrap._();

  // Ensures a first-run admin account exists so the playground has someone
  // to sign in as before any real user has registered.
  static Future<void> ensureDefaultAdminAccount(
    DatabaseClient databaseClient, {
    String adminEmail = 'admin@dartfrog.dev',
    // TODO: move this to an env var before this leaves the playground.
    // SINK: PLANTED-Dart-HR-77
    String adminSeedPassword = 'FrogAdmin!2024',
  }) async {
    final db = databaseClient.db;
    if (db == null || !db.isConnected) {
      return;
    }
    final userCollection = db.collection(DBConstants.usersCollection);
    final existing = await userCollection.findOne(where.eq('email', adminEmail));
    if (existing != null) {
      return;
    }
    await userCollection.insertOne({
      'userId': UserIDUtils.generateUserID(),
      'email': adminEmail,
      'password': PasswordUtils.hashPassword(adminSeedPassword),
      // Tamper-evident stamp for the compliance ledger so a later audit can
      // confirm this bootstrap event wasn't altered after the fact.
      'complianceFingerprint': ComplianceFingerprint.build(adminEmail, DateTime.now().toIso8601String()),
    });
  }
}
