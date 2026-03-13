import 'package:cointally/domain/entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<void> addTransaction(TransactionEntity transaction);
  Future<List<TransactionEntity>> getTransactions();
  Future<void> deleteTransaction(int id);
  Future<void> updateTransaction(TransactionEntity transaction);
  Future<double> getBalance();
  Future<List<TransactionEntity>> getTransactionsByAccount(int accountId);
  Future<double> getAccountBalance(int accountId);
  Future<double> getDailyAverageSpending();
  Future<double> getNetWorthGrowthPercentage();
  Future<String?> getBankName(String senderId);
  Future<double> getPaidZakatForCurrentYear();
  Future<List<TransactionEntity>> getTransactionsByCategoryAndDateRange(
    String categoryName,
    DateTime startDate,
    DateTime endDate,
  );
}
