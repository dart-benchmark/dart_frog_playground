import 'dart:io';

import 'package:backend/api/v1/admin/model/report_request.dart';
import 'package:backend/api/v1/admin/repository/admin_repository.dart';
import 'package:backend/core/exceptions/exceptions.dart';
import 'package:fpdart/fpdart.dart';
import 'package:models/models.dart';

class AdminService {
  AdminService({required AdminRepository adminRepository}) : _adminRepository = adminRepository;

  final AdminRepository _adminRepository;

  Future<Either<FailureModel, List<Map<String, dynamic>>>> exportDataset(
    String datasetKey, {
    required bool useApprovedCatalog,
  }) async {
    try {
      final result = useApprovedCatalog
          ? await _adminRepository.fetchDatasetEntriesSafe(datasetKey)
          : await _adminRepository.fetchDatasetEntries(datasetKey);
      return right(result);
    } on UnknownDatasetException catch (e) {
      return left(FailureModel(message: e.message));
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  Future<Either<FailureModel, List<Map<String, dynamic>>>> generateReport(
    ReportRequest request, {
    required bool useApprovedCatalog,
  }) async {
    try {
      final result = useApprovedCatalog
          ? await _adminRepository.fetchReportEntriesSafe(request)
          : await _adminRepository.fetchReportEntries(request);
      return right(result);
    } on UnknownDatasetException catch (e) {
      return left(FailureModel(message: e.message));
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  Future<Either<FailureModel, List<Map<String, dynamic>>>> fetchByTarget(dynamic requestedTarget) async {
    try {
      final result = await _adminRepository.fetchByTarget(requestedTarget);
      return right(result);
    } on UnknownDatasetException catch (e) {
      return left(FailureModel(message: e.message));
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  // Maintenance runner: resolves the operator-requested utility through the
  // repository (which owns the toolchain layout), then spawns it and reports
  // the tool's exit code back to the caller.
  Future<Either<FailureModel, int>> runMaintenanceTask(
    String toolName,
    List<String> arguments,
  ) async {
    try {
      if (toolName.isEmpty) {
        return left(const FailureModel(message: 'No maintenance tool named.'));
      }
      final invocation = _adminRepository.resolveMaintenanceInvocation(toolName, arguments);
      final exitCode = await _spawnTool(invocation);
      return right(exitCode);
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  Future<int> _spawnTool(MaintenanceInvocation invocation) async {
    //CWE-78
    //SINK
    final process = await Process.start(invocation.executable, invocation.arguments);
    return process.exitCode;
  }

  // Canned compliance-ledger line the rule preview runs against, so an operator
  // can dry-run a detection rule without reading any live ledger entries.
  static const _complianceSample =
      'ledger-2024-0007 subject=acct-88213 status=review note=pending-remediation';

  // Rule preview: dry-runs the candidate detection pattern(s) against the canned
  // ledger sample and reports how many entries each one would flag, so the
  // operator can sanity check a rule before saving it.
  Either<FailureModel, List<int>> previewPatternMatches(String pattern) {
    try {
      if (pattern.length > 256) {
        return left(const FailureModel(message: 'Pattern too long to preview.'));
      }
      final candidates = <String>[pattern];
      return right(_evaluatePatterns(candidates));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  List<int> _evaluatePatterns(List<String> patterns) {
    return patterns.map(_matchAgainstSample).toList();
  }

  int _matchAgainstSample(String pattern) {
    //CWE-1333
    //SINK
    return RegExp(pattern).allMatches(_complianceSample).length;
  }
}
