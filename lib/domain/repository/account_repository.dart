import 'package:cointally/domain/entities/account_entity.dart';

abstract class AccountRepository {
  Future<int> addAccount(AccountEntity account);
  Future<List<AccountEntity>> getAllAccounts();
  Future<void> updateAccount(AccountEntity account);
  Future<void> deleteAccount(int id);
  Future<void> setDefaultAccount(int id);
}
