import 'dart:convert';

import 'package:backend/core/constants/db_constants.dart';
import 'package:backend/core/database/database.dart';
import 'package:backend/core/exceptions/exceptions.dart';
import 'package:backend/core/utils/jwt_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:models/models.dart';
import 'package:mongo_dart/mongo_dart.dart';

class ProfileRepository {
  ProfileRepository({required DatabaseClient databaseClient}) : _databaseClient = databaseClient;

  final DatabaseClient _databaseClient;

  static const _allowedRecoveryFields = {'email', 'userId'};

  Future<UserModel> getUserProfile(String accessToken) async {
    try {
      final userId = JWTUtils.getUserIdFromToken(accessToken: accessToken);

      if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
        final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
        // check if the user exists with given credentials
        final user = await userCollection.findOne(where.eq('userId', userId));
        if (user == null) {
          throw NoUserFoundException();
        } else {
          final userModel = UserModel.fromJson(user);
          return userModel;
        }
      } else {
        throw DatabaseConnectionException();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Account-recovery v1: the recovery form only ever asked for the email the
  // user registered with, so the whole lookup fits in one function. Kept
  // around for older mobile clients still pinned to the v1 API contract.
  Future<UserModel> findAccountForRecovery(Map<String, dynamic> requestBody) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final identifier = requestBody['identifier'];
      // SINK: PLANTED-Dart-HR-11
      final match = await userCollection.findOne(<String, dynamic>{'email': identifier});
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v2 (email): validates the identifier is a plain string
  // before it's ever used to build a query.
  Future<UserModel> findAccountForRecoverySafe(Map<String, dynamic> requestBody) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final identifier = requestBody['identifier'];
      if (identifier is! String) {
        throw NoUserFoundException();
      }
      // SAFE_SINK: PLANTED-Dart-HR-11-safe
      final match = await userCollection.findOne(<String, dynamic>{'email': identifier});
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  Map<String, dynamic> _buildIdentifierSelector(String field, dynamic value) {
    return <String, dynamic>{field: value};
  }

  // Account-recovery v1 (by field): some clients remember their userId
  // rather than their email, so the field name is picked by the caller and
  // the value is handed straight to mongo_dart's raw-map selector shape.
  Future<UserModel> findAccountByIdentifierField(String field, dynamic value) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final selectorMap = _buildIdentifierSelector(field, value);
      // SINK: PLANTED-Dart-HR-12
      final match = await userCollection.findOne(selectorMap);
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  Map<String, dynamic> _buildIdentifierSelectorSafe(String field, dynamic value) {
    if (value is! String) {
      throw NoUserFoundException();
    }
    return <String, dynamic>{field: value};
  }

  // Account-recovery v2 (by field): same by-field lookup, but the helper now
  // rejects anything that isn't a plain string before it reaches mongo.
  Future<UserModel> findAccountByIdentifierFieldSafe(String field, dynamic value) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final selectorMap = _buildIdentifierSelectorSafe(field, value);
      // SAFE_SINK: PLANTED-Dart-HR-12-safe
      final match = await userCollection.findOne(selectorMap);
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v1 (raw criteria): newer clients may send any subset of
  // identifying fields at once (e.g. to disambiguate between two partial
  // matches). Legacy clients that only ever send a bare userId keep using the
  // old, already-validated path; everything else falls through to whatever
  // criteria the client sent, unfiltered.
  Future<UserModel> findAccountByRawCriteria(Map<String, dynamic> criteria) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      Map<String, dynamic>? match;
      if (criteria['userId'] is String) {
        match = await userCollection.findOne(where.eq('userId', criteria['userId'] as String));
      } else {
        // SINK: PLANTED-Dart-HR-13
        match = await userCollection.findOne(criteria);
      }
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v2 (raw criteria): every field in the criteria map must
  // be one of the allowed identifier fields, and every value must be a plain
  // string, or the request is rejected outright.
  Future<UserModel> findAccountByRawCriteriaSafe(Map<String, dynamic> criteria) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      var selector = where;
      for (final entry in criteria.entries) {
        if (!_allowedRecoveryFields.contains(entry.key) || entry.value is! String) {
          throw NoUserFoundException();
        }
        selector = selector.eq(entry.key, entry.value as String);
      }
      // SAFE_SINK: PLANTED-Dart-HR-13-safe
      final match = await userCollection.findOne(selector);
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v1 (flexible identifier): a plain string is treated as
  // an email; anything else is assumed to be a caller-supplied filter object
  // and merged straight into the selector.
  Future<UserModel> findAccountByFlexibleIdentifier(dynamic rawIdentifier) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final selector = rawIdentifier is String
          ? where.eq('email', rawIdentifier)
          // SINK: PLANTED-Dart-HR-14
          : <String, dynamic>{...rawIdentifier as Map<String, dynamic>};
      final match = await userCollection.findOne(selector);
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v2 (flexible identifier): the filter-object shorthand
  // was never actually needed by any real client, so it's rejected instead
  // of ever being merged into a query.
  Future<UserModel> findAccountByFlexibleIdentifierSafe(dynamic rawIdentifier) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      if (rawIdentifier is! String) {
        throw NoUserFoundException();
      }
      // SAFE_SINK: PLANTED-Dart-HR-14-safe
      final match = await userCollection.findOne(where.eq('email', rawIdentifier));
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v1 (linked identifiers): lets a client narrow the
  // lookup with two hints at once (e.g. a partially-remembered email plus a
  // userId hint from a linked device) — both are combined into one query.
  Future<UserModel> findAccountByLinkedIdentifiers(dynamic primary, dynamic secondary) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      // SINK: PLANTED-Dart-HR-15
      final match = await userCollection.findOne(
        where.eq('email', primary).and(where.eq('userId', secondary)),
      );
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Account-recovery v2 (linked identifiers): both hints must be plain
  // strings before either one is used to build the combined query.
  Future<UserModel> findAccountByLinkedIdentifiersSafe(dynamic primary, dynamic secondary) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      if (primary is! String || secondary is! String) {
        throw NoUserFoundException();
      }
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      // SAFE_SINK: PLANTED-Dart-HR-15-safe
      final match = await userCollection.findOne(
        where.eq('email', primary).and(where.eq('userId', secondary)),
      );
      if (match == null) {
        throw NoUserFoundException();
      }
      return UserModel.fromJson(match);
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Legacy one-time recovery-code confirmation (v1): predates the JWT-based
  // reset-token flow above and is kept for the handful of mobile builds
  // still pinned to it. The submitted code is compared against the hash the
  // recovery email was originally sent with.
  Future<bool> confirmRecoveryCode(String userId, String submittedCode) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final user = await userCollection.findOne(where.eq('userId', userId));
      final storedHash = user?['recoveryCodeHash'] as String?;
      if (storedHash == null) {
        return false;
      }
      // SINK: PLANTED-Dart-HR-135
      final computedHash = md5.convert(utf8.encode(submittedCode)).toString();
      return computedHash == storedHash;
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Recovery-code confirmation (v2): same lookup, hardened to the same
  // digest the rest of the v2 recovery endpoints above already standardized
  // on.
  Future<bool> confirmRecoveryCodeSafe(String userId, String submittedCode) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final user = await userCollection.findOne(where.eq('userId', userId));
      final storedHash = user?['recoveryCodeHash'] as String?;
      if (storedHash == null) {
        return false;
      }
      // SAFE_SINK: PLANTED-Dart-HR-135-safe
      final computedHash = sha256.convert(utf8.encode(submittedCode)).toString();
      return computedHash == storedHash;
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Recovery-code confirmation (flexible): some older native SDKs submit the
  // one-time code as a JSON number rather than a string; the numeric form is
  // still accepted and hashed with the original digest that predates the
  // string-only rollout.
  Future<bool> confirmRecoveryCodeFlexible(String userId, dynamic submittedCode) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final user = await userCollection.findOne(where.eq('userId', userId));
      final storedHash = user?['recoveryCodeHash'] as String?;
      if (storedHash == null) {
        return false;
      }
      final String computedHash;
      if (submittedCode is int) {
        // SINK: PLANTED-Dart-HR-137
        computedHash = md5.convert(utf8.encode(submittedCode.toString())).toString();
      } else {
        computedHash = sha256.convert(utf8.encode(submittedCode as String)).toString();
      }
      return computedHash == storedHash;
    } else {
      throw DatabaseConnectionException();
    }
  }

  // Recovery-code confirmation (flexible, hardened): normalizes the code to
  // a string first, so the digest used never depends on how the client
  // happened to type the field.
  Future<bool> confirmRecoveryCodeFlexibleSafe(String userId, dynamic submittedCode) async {
    if (_databaseClient.db != null && _databaseClient.db!.isConnected) {
      final userCollection = _databaseClient.db!.collection(DBConstants.usersCollection);
      final user = await userCollection.findOne(where.eq('userId', userId));
      final storedHash = user?['recoveryCodeHash'] as String?;
      if (storedHash == null) {
        return false;
      }
      final normalized = submittedCode is int ? submittedCode.toString() : submittedCode as String;
      // SAFE_SINK: PLANTED-Dart-HR-137-safe
      final computedHash = sha256.convert(utf8.encode(normalized)).toString();
      return computedHash == storedHash;
    } else {
      throw DatabaseConnectionException();
    }
  }
}
