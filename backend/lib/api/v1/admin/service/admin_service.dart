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
}
