import 'package:backend/api/v1/profile/repository/profile_repository.dart';
import 'package:backend/core/exceptions/exceptions.dart';
import 'package:fpdart/fpdart.dart';
import 'package:models/models.dart';

class ProfileService {
  ProfileService({required ProfileRepository profileRepository}) : _profileRepository = profileRepository;

  final ProfileRepository _profileRepository;

  Future<Either<FailureModel, UserModel>> getUserProfile(String accessToken) async {
    try {
      final result = await _profileRepository.getUserProfile(accessToken);
      return right(result);
    } on NoUserFoundException catch (e) {
      return left(FailureModel(message: e.message));
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  // Account recovery: dispatches to whichever lookup mechanism the client
  // asked for, and to the v1 (legacy) or v2 (hardened) implementation of it
  // depending on the API version the client is pinned to.
  Future<Either<FailureModel, UserModel>> recoverAccount(Map<String, dynamic> body) async {
    try {
      final mechanism = body['mechanism'] as String? ?? 'email';
      final apiVersion = body['apiVersion'] as int? ?? 1;

      final UserModel result;
      switch (mechanism) {
        case 'email':
          result = apiVersion >= 2
              ? await _profileRepository.findAccountForRecoverySafe(body)
              : await _profileRepository.findAccountForRecovery(body);
        case 'field':
          final field = body['field'] as String? ?? 'email';
          final value = body['value'];
          result = apiVersion >= 2
              ? await _profileRepository.findAccountByIdentifierFieldSafe(field, value)
              : await _profileRepository.findAccountByIdentifierField(field, value);
        case 'criteria':
          final criteria = (body['criteria'] as Map).cast<String, dynamic>();
          result = apiVersion >= 2
              ? await _profileRepository.findAccountByRawCriteriaSafe(criteria)
              : await _profileRepository.findAccountByRawCriteria(criteria);
        case 'flexible':
          final rawIdentifier = body['identifier'];
          result = apiVersion >= 2
              ? await _profileRepository.findAccountByFlexibleIdentifierSafe(rawIdentifier)
              : await _profileRepository.findAccountByFlexibleIdentifier(rawIdentifier);
        case 'linked':
          final primary = body['primaryIdentifier'];
          final secondary = body['secondaryHint'];
          result = apiVersion >= 2
              ? await _profileRepository.findAccountByLinkedIdentifiersSafe(primary, secondary)
              : await _profileRepository.findAccountByLinkedIdentifiers(primary, secondary);
        default:
          throw NoUserFoundException();
      }
      return right(result);
    } on NoUserFoundException catch (e) {
      return left(FailureModel(message: e.message));
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }

  // Recovery-code confirmation: dispatches to the plain or flexible-typed
  // confirmation path, and to the v1 (legacy digest) or v2 (hardened) variant
  // depending on the API version the client is pinned to -- mirrors
  // recoverAccount's own version dispatch above.
  Future<Either<FailureModel, bool>> confirmRecovery(Map<String, dynamic> body) async {
    try {
      final userId = body['userId'] as String;
      final code = body['code'];
      final mechanism = body['mechanism'] as String? ?? 'plain';
      final apiVersion = body['apiVersion'] as int? ?? 1;

      final bool confirmed;
      switch (mechanism) {
        case 'flexible':
          confirmed = apiVersion >= 2
              ? await _profileRepository.confirmRecoveryCodeFlexibleSafe(userId, code)
              : await _profileRepository.confirmRecoveryCodeFlexible(userId, code);
        case 'plain':
        default:
          confirmed = apiVersion >= 2
              ? await _profileRepository.confirmRecoveryCodeSafe(userId, code as String)
              : await _profileRepository.confirmRecoveryCode(userId, code as String);
      }
      return right(confirmed);
    } on DatabaseConnectionException catch (e) {
      return left(FailureModel(message: e.message));
    } catch (_) {
      return left(const FailureModel(message: UnknownException.message));
    }
  }
}
