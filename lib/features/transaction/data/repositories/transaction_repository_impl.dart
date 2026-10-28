import 'dart:convert';
import 'dart:developer' as developer;

import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../product/data/models/product_model.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  static const String boxName = 'transactions_v1';
  static const String counterKey = 'transaction_counter';

  Box<String>? _box;
  Box<String>? get box => _box ?? HiveDatabase.settingsBox;

  Future<Box<String>> _openBox() async {
    if (_box != null) return _box!;
    _box = await Hive.openBox<String>(boxName);
    return _box!;
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactions() async {
    try {
      final target = await _openBox();
      final list = <Transaction>[];
      for (final key in target.keys) {
        final raw = target.get(key);
        if (raw == null) {
          developer.log(
            'Transaction record with key "$key" has no stored value.',
            name: 'TransactionRepository',
          );
          continue;
        }
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(Transaction.fromJson(decoded));
          } else {
            developer.log(
              'Transaction record with key "$key" is not a JSON object.',
              name: 'TransactionRepository',
            );
          }
        } catch (error, stackTrace) {
          developer.log(
            'Failed to decode transaction record with key "$key".',
            name: 'TransactionRepository',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(list);
    } catch (e) {
      return Left(CacheFailure('Gagal membaca riwayat transaksi.'));
    }
  }

  @override
  Future<Either<Failure, Transaction?>> getTransactionById(String id) async {
    try {
      final target = await _openBox();
      final raw = target.get(id);
      if (raw == null) return const Right(null);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Right(Transaction.fromJson(decoded));
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Gagal membaca transaksi.'));
    }
  }

  @override
  Future<Either<Failure, String>> generateTransactionNumber() async {
    try {
      final settingsBox = HiveDatabase.settingsBox;
      int counter = settingsBox.get(counterKey) ?? 0;
      counter += 1;
      await settingsBox.put(counterKey, counter);
      final stamp = DateTime.now();
      final date = '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
      return Right('INV-$date-${counter.toString().padLeft(4, '0')}');
    } catch (e) {
      return Left(CacheFailure('Gagal membuat nomor transaksi.'));
    }
  }

  @override
  Future<Either<Failure, void>> saveTransaction(Transaction transaction) async {
    final changedProducts = <String, ProductModel>{};
    final originalProducts = <String, ProductModel>{};
    try {
      final target = await _openBox();
      if (target.containsKey(transaction.id)) {
        return const Left(CacheFailure('Transaksi dengan ID ini sudah tersimpan.'));
      }

      final quantities = <String, int>{};
      for (final item in transaction.items.where((item) => item.type == 'product')) {
        final productId = item.masterRef ?? item.id;
        quantities.update(
          productId,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }

      final products = HiveDatabase.productBox;
      for (final entry in quantities.entries) {
        final product = products.get(entry.key);
        if (product == null) {
          return Left(CacheFailure('Produk ${entry.key} tidak ditemukan.'));
        }
        if (entry.value <= 0 || product.stock < entry.value) {
          return Left(CacheFailure(
            'Stok ${product.name} tidak mencukupi (tersedia ${product.stock}).',
          ));
        }
        originalProducts[entry.key] = product;
        changedProducts[entry.key] = ProductModel(
          id: product.id,
          name: product.name,
          barcode: product.barcode,
          price: product.price,
          stock: product.stock - entry.value,
        );
      }

      for (final entry in changedProducts.entries) {
        await products.put(entry.key, entry.value);
      }

      final payload = jsonEncode(transaction.toJson());
      await target.put(transaction.id, payload);
      return const Right(null);
    } catch (e) {
      try {
        for (final entry in originalProducts.entries) {
          await HiveDatabase.productBox.put(entry.key, entry.value);
        }
      } catch (rollbackError) {
        return Left(CacheFailure(
          'Gagal menyimpan transaksi dan memulihkan stok: $rollbackError',
        ));
      }
      return Left(CacheFailure('Gagal menyimpan transaksi: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addPayment(String transactionId, PaymentRecord payment) async {
    try {
      final txResult = await getTransactionById(transactionId);
      if (txResult.isLeft()) {
        return txResult.fold((fail) => Left(fail), (_) => const Right(null));
      }
      final current = txResult.getRight().toNullable();
      if (current == null) {
        return Left(CacheFailure('Transaksi tidak ditemukan.'));
      }
      if (payment.transactionId != transactionId || payment.amount <= 0) {
        return const Left(CacheFailure('Data pembayaran tidak valid.'));
      }
      if (current.payments.any((record) => record.id == payment.id)) {
        return const Right(null);
      }
      if (payment.amount > current.remainingBalance) {
        return const Left(CacheFailure('Pembayaran melebihi sisa tagihan.'));
      }

      final updated = current.addPayment(payment);
      if (updated == current) {
        return const Left(CacheFailure('Pembayaran tidak dapat ditambahkan.'));
      }
      final target = await _openBox();
      await target.put(transactionId, jsonEncode(updated.toJson()));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Gagal menambahkan pembayaran: $e'));
    }
  }
}
