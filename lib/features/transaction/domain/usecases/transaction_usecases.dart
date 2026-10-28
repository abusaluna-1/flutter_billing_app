import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionsUseCase implements UseCase<List<Transaction>, NoParams> {
  final TransactionRepository repository;

  GetTransactionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Transaction>>> call(NoParams params) => repository.getTransactions();
}

class GenerateTransactionNumberUseCase implements UseCase<String, NoParams> {
  final TransactionRepository repository;

  GenerateTransactionNumberUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) => repository.generateTransactionNumber();
}

class SaveTransactionUseCase implements UseCase<void, Transaction> {
  final TransactionRepository repository;

  SaveTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Transaction params) => repository.saveTransaction(params);
}

class GetTransactionByIdUseCase implements UseCase<Transaction?, String> {
  final TransactionRepository repository;

  GetTransactionByIdUseCase(this.repository);

  @override
  Future<Either<Failure, Transaction?>> call(String params) => repository.getTransactionById(params);
}

class AddPaymentUseCase implements UseCase<void, PaymentRecord> {
  final TransactionRepository repository;

  AddPaymentUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(PaymentRecord params) => repository.addPayment(params.transactionId, params);
}
