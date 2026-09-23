import 'package:backend/api/v1/admin/model/report_request.dart';
import 'package:backend/core/constants/db_constants.dart';
import 'package:backend/core/database/database.dart';
import 'package:backend/core/exceptions/exceptions.dart';

class AdminRepository {
  AdminRepository({required DatabaseClient databaseClient}) : _databaseClient = databaseClient;

  final DatabaseClient _databaseClient;

  // Datasets an operator is actually allowed to export through this
  // endpoint -- deliberately a small, fixed catalog rather than "whatever
  // collection happens to exist in the cluster."
  static const _approvedDatasets = {
    'compliance': DBConstants.complianceLedgerCollection,
    'orders': DBConstants.tenantOrdersCollection,
  };

  // Same catalog, reused by the report endpoint below.
  static const _approvedReportCollections = {
    'compliance': DBConstants.complianceLedgerCollection,
    'orders': DBConstants.tenantOrdersCollection,
    'audit': DBConstants.auditLogCollection,
  };

  // Data-export (v1): resolves a caller-supplied dataset key straight into a
  // Mongo collection name, so operators can dump any dataset without a code
  // change every time compliance asks for a new export type.
  Future<List<Map<String, dynamic>>> fetchDatasetEntries(String datasetKey) async {
    if (_databaseClient.db == null || !_databaseClient.db!.isConnected) {
      throw DatabaseConnectionException();
    }
    // SINK: PLANTED-Dart-HR-702
    final dataset = _databaseClient.db!.collection(datasetKey);
    return dataset.find().take(100).toList();
  }

  // Data-export (v2): the dataset key must be one of the exports compliance
  // has actually approved for this endpoint.
  Future<List<Map<String, dynamic>>> fetchDatasetEntriesSafe(String datasetKey) async {
    if (_databaseClient.db == null || !_databaseClient.db!.isConnected) {
      throw DatabaseConnectionException();
    }
    final resolved = _approvedDatasets[datasetKey];
    if (resolved == null) {
      throw UnknownDatasetException();
    }
    // SAFE_SINK: PLANTED-Dart-HR-702-safe
    final dataset = _databaseClient.db!.collection(resolved);
    return dataset.find().take(100).toList();
  }

  // Report generation (v1): the target collection was captured earlier, up
  // in the route handler, from the caller-supplied `X-Report-Collection`
  // header and threaded down here on the request object's own field.
  Future<List<Map<String, dynamic>>> fetchReportEntries(ReportRequest request) async {
    if (_databaseClient.db == null || !_databaseClient.db!.isConnected) {
      throw DatabaseConnectionException();
    }
    // SINK: PLANTED-Dart-HR-703
    final target = _databaseClient.db!.collection(request.targetCollection);
    return target.find().take(50).toList();
  }

  // Report generation (v2): the requested target collection must be one of
  // the collections this report feature is actually approved to read.
  Future<List<Map<String, dynamic>>> fetchReportEntriesSafe(ReportRequest request) async {
    if (_databaseClient.db == null || !_databaseClient.db!.isConnected) {
      throw DatabaseConnectionException();
    }
    final resolved = _approvedReportCollections[request.targetCollection];
    if (resolved == null) {
      throw UnknownDatasetException();
    }
    // SAFE_SINK: PLANTED-Dart-HR-703-safe
    final target = _databaseClient.db!.collection(resolved);
    return target.find().take(50).toList();
  }

  // Dataset lookup by target (v1/v2 in one place): newer clients send a
  // structured `{"category": "..."}` selector; a handful of older internal
  // scripts, predating the catalog rollout, still send the target Mongo
  // collection name directly as a bare string -- both shapes are accepted by
  // the same endpoint for backward compatibility, but only one of them is
  // actually safe.
  Future<List<Map<String, dynamic>>> fetchByTarget(dynamic requestedTarget) async {
    if (_databaseClient.db == null || !_databaseClient.db!.isConnected) {
      throw DatabaseConnectionException();
    }
    if (requestedTarget is String) {
      // Legacy bare-string form: whatever the caller sent IS the collection
      // name, unchanged.
      // SINK: PLANTED-Dart-HR-704
      final dataset = _databaseClient.db!.collection(requestedTarget);
      return dataset.find().take(50).toList();
    } else if (requestedTarget is Map) {
      final category = requestedTarget['category'];
      final resolved = category is String ? _approvedDatasets[category] : null;
      if (resolved == null) {
        throw UnknownDatasetException();
      }
      // SAFE_SINK: PLANTED-Dart-HR-704-safe
      final dataset = _databaseClient.db!.collection(resolved);
      return dataset.find().take(50).toList();
    } else {
      throw UnknownDatasetException();
    }
  }
}
