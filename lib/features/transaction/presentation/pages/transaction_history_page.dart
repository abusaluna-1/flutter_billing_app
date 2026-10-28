import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/usecase/usecase.dart';
import 'package:billing_app/core/utils/rupiah.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/transaction_usecases.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  late Future<Either<Failure, List<Transaction>>> _transactions;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    _transactions = sl<GetTransactionsUseCase>()(NoParams());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: FutureBuilder<Either<Failure, List<Transaction>>>(
        future: _transactions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat transaksi: ${snapshot.error}'));
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Tidak ada data transaksi.'));
          }
          return result.fold<Widget>(
            (failure) => Center(child: Text(failure.message)),
            (transactions) {
              if (transactions.isEmpty) {
                return const Center(child: Text('Belum ada transaksi tersimpan.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_loadTransactions);
                  await _transactions;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _transactionCard(context, transactions[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _transactionCard(BuildContext context, Transaction transaction) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/transactions/${transaction.id}'),
        title: Text(transaction.transactionNumber,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt)}\n'
          '${transaction.customer.name} • '
          'Dibayar ${formatRupiah(transaction.totalPaid)} • '
          'Sisa ${formatRupiah(transaction.remainingBalance)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatRupiah(transaction.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(transaction.status.label,
                style: TextStyle(
                    color: transaction.status == TransactionStatus.paid
                        ? Colors.green
                        : Colors.orange,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
