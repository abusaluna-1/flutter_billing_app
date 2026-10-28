import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/transaction.dart';

abstract class TransactionRepository {
  Future<Either<Failure, List<Transaction>>> getTransactions();
  Future<Either<Failure, Transaction?>> getTransactionById(String id);
  Future<Either<Failure, String>> generateTransactionNumber();
  Future<Either<Failure, void>> saveTransaction(Transaction transaction);
  Future<Either<Failure, void>> addPayment(String transactionId, PaymentRecord payment);
}
