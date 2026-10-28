import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/error/failure.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/utils/printer_helper.dart';
import 'package:billing_app/core/utils/rupiah.dart';
import 'package:billing_app/features/shop/presentation/bloc/shop_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/usecases/transaction_usecases.dart';

class TransactionDetailPage extends StatefulWidget {
  final String transactionId;

  const TransactionDetailPage({super.key, required this.transactionId});

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late Future<Either<Failure, Transaction?>> _transaction;
  bool _isAddingPayment = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  void _loadTransaction() {
    _transaction =
        sl<GetTransactionByIdUseCase>()(widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: FutureBuilder<Either<Failure, Transaction?>>(
        future: _transaction,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat transaksi: ${snapshot.error}'));
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Transaksi tidak ditemukan.'));
          }
          return result.fold<Widget>(
            (failure) => Center(child: Text(failure.message)),
            (transaction) => transaction == null
                ? const Center(child: Text('Transaksi tidak ditemukan.'))
                : _details(transaction),
          );
        },
      ),
    );
  }

  Widget _details(Transaction transaction) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(transaction.transactionNumber,
            style: Theme.of(context).textTheme.titleLarge),
        Text(DateFormat('dd/MM/yyyy HH:mm').format(transaction.createdAt)),
        const SizedBox(height: 16),
        _info('Customer', transaction.customer.name),
        _info('Nomor HP', transaction.customer.phone.isEmpty
            ? '-'
            : transaction.customer.phone),
        _info('Admin/kasir', transaction.adminName),
        _info('Status', transaction.status.label),
        const Divider(height: 28),
        const Text('Item',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ...transaction.items.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text(
                  '${item.quantity} x ${formatRupiah(item.price)}'),
              trailing: Text(formatRupiah(item.subtotal)),
            )),
        const Divider(),
        _info('Total transaksi', formatRupiah(transaction.grandTotal)),
        _info('Total dibayar', formatRupiah(transaction.totalPaid)),
        _info('Sisa pembayaran', formatRupiah(transaction.remainingBalance),
            bold: true),
        const SizedBox(height: 16),
        const Text('Riwayat Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (transaction.payments.isEmpty)
          const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Belum ada pembayaran'))
        else
          ...transaction.payments.map((payment) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatRupiah(payment.amount)),
                subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt)}'
                    ' • ${payment.method} • ${payment.adminName}'),
              )),
        const SizedBox(height: 16),
        if (transaction.remainingBalance > 0)
          FilledButton.icon(
            onPressed: _isAddingPayment
                ? null
                : () => _addPayment(transaction),
            icon: const Icon(Icons.payments_outlined),
            label: Text(_isAddingPayment ? 'Menyimpan...' : 'Tambah Pembayaran'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isPrinting ? null : () => _printTransaction(transaction),
          icon: const Icon(Icons.print),
          label: Text(_isPrinting ? 'Mencetak...' : 'Cetak Ulang Struk'),
        ),
      ],
    );
  }

  Widget _info(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            ),
          ],
        ),
      );

  Future<void> _addPayment(Transaction transaction) async {
    final controller = TextEditingController();
    var method = 'Tunai';
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sisa tagihan: ${formatRupiah(transaction.remainingBalance)}'),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
              ),
              DropdownButtonFormField<String>(
                value: method,
                decoration:
                    const InputDecoration(labelText: 'Metode pembayaran'),
                items: const ['Tunai', 'Transfer', 'QRIS', 'Kartu']
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => method = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null ||
                    value <= 0 ||
                    value > transaction.remainingBalance) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Nominal pembayaran tidak valid')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (amount == null || !mounted) {
      controller.dispose();
      return;
    }

    setState(() => _isAddingPayment = true);
    final payment = PaymentRecord(
      id: const Uuid().v4(),
      transactionId: transaction.id,
      amount: amount,
      paidAt: DateTime.now(),
      method: method,
      adminName:
          HiveDatabase.settingsBox.get('active_admin_name', defaultValue: ''),
    );
    try {
      final result = await sl<AddPaymentUseCase>()(payment);
      if (!mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(failure.message), backgroundColor: Colors.red)),
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Pembayaran tersimpan'),
              backgroundColor: Colors.green));
          setState(_loadTransaction);
        },
      );
    } finally {
      controller.dispose();
      if (mounted) setState(() => _isAddingPayment = false);
    }
  }

  Future<void> _printTransaction(Transaction transaction) async {
    final shopState = context.read<ShopBloc>().state;
    if (shopState is! ShopLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data bengkel belum termuat'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final printer = PrinterHelper();
      if (!printer.isConnected) {
        final mac = HiveDatabase.settingsBox.get('printer_mac');
        if (mac == null || !await printer.connect(mac)) {
          throw StateError('Printer belum tersambung.');
        }
      }
      await printer.printReceipt(
        shopName: shopState.shop.name,
        address1: shopState.shop.addressLine1,
        address2: shopState.shop.addressLine2,
        phone: shopState.shop.phoneNumber,
        footer: shopState.shop.footerText,
        items: transaction.items
            .map((item) => {
                  'name': item.name,
                  'qty': item.quantity,
                  'price': item.price,
                  'total': item.subtotal,
                })
            .toList(),
        total: transaction.grandTotal.toDouble(),
        transactionNumber: transaction.transactionNumber,
        customerName: transaction.customer.name,
        customerPhone: transaction.customer.phone,
        adminName: transaction.adminName,
        paid: transaction.totalPaid,
        remaining: transaction.remainingBalance,
        createdAt: transaction.createdAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Struk berhasil dicetak'),
            backgroundColor: Colors.green));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal mencetak struk: $error'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}
