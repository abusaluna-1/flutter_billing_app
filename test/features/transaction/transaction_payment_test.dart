import 'package:billing_app/features/transaction/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transaction = Transaction(
    id: 'tx-1',
    transactionNumber: 'INV-1',
    createdAt: DateTime(2026, 10, 28),
    grandTotal: 100000,
    remainingBalance: 100000,
  );

  PaymentRecord payment({
    required String id,
    required int amount,
  }) =>
      PaymentRecord(
        id: id,
        transactionId: transaction.id,
        amount: amount,
        paidAt: DateTime(2026, 10, 28),
        method: 'Tunai',
        adminName: 'Kasir',
      );

  test('mencatat pembayaran bertahap dan menghitung status DP', () {
    final updated = transaction.addPayment(payment(id: 'pay-1', amount: 30000));

    expect(updated.totalPaid, 30000);
    expect(updated.remainingBalance, 70000);
    expect(updated.status, TransactionStatus.partial);
    expect(updated.status.label, 'DP');
  });

  test('ID pembayaran duplikat tidak menambah nominal dua kali', () {
    final first = transaction.addPayment(payment(id: 'same-id', amount: 30000));
    final duplicate =
        first.addPayment(payment(id: 'same-id', amount: 30000));

    expect(duplicate.payments, hasLength(1));
    expect(duplicate.totalPaid, 30000);
  });

  test('pembayaran yang melampaui sisa tagihan ditolak', () {
    final updated = transaction.addPayment(payment(id: 'pay-over', amount: 100001));

    expect(updated, transaction);
    expect(updated.totalPaid, 0);
    expect(updated.status, TransactionStatus.pending);
  });

  test('pelunasan mengubah status menjadi lunas', () {
    final updated = transaction.addPayment(payment(id: 'pay-full', amount: 100000));

    expect(updated.remainingBalance, 0);
    expect(updated.status, TransactionStatus.paid);
    expect(updated.status.label, 'Lunas');
  });
}
