import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/usecase/usecase.dart';
import 'package:billing_app/core/utils/rupiah.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart'hide State;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/transaction_usecases.dart';

enum _ReportPeriod { today, month, range }

class TransactionReportPage extends StatefulWidget {
  const TransactionReportPage({super.key});

  @override
  State<TransactionReportPage> createState() => _TransactionReportPageState();
}

class _TransactionReportPageState extends State<TransactionReportPage> {
  late Future<Either<Failure, List<Transaction>>> _transactions;
  _ReportPeriod _period = _ReportPeriod.today;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _transactions = sl<GetTransactionsUseCase>()(NoParams());
  }

  DateTimeRange get _activeRange {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: start);
      case _ReportPeriod.month:
        final start = DateTime(now.year, now.month);
        return DateTimeRange(
            start: start, end: DateTime(now.year, now.month + 1, 0));
      case _ReportPeriod.range:
        return _dateRange ??
            DateTimeRange(
                start: DateTime(now.year, now.month, now.day),
                end: DateTime(now.year, now.month, now.day));
    }
  }

  bool _within(DateTime value, DateTimeRange range) {
    final date = DateTime(value.year, value.month, value.day);
    return !date.isBefore(range.start) &&
        !date.isAfter(range.end);
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange ??
          DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day)),
    );
    if (range != null) {
      setState(() {
        _period = _ReportPeriod.range;
        _dateRange = range;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Transaksi')),
      body: FutureBuilder<Either<Failure, List<Transaction>>>(
        future: _transactions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat laporan: ${snapshot.error}'));
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Data laporan tidak tersedia.'));
          }
          return result.fold<Widget>(
            (failure) => Center(child: Text(failure.message)),
            (transactions) => _report(transactions),
          );
        },
      ),
    );
  }

  Widget _report(List<Transaction> allTransactions) {
    final range = _activeRange;
    final transactions =
        allTransactions.where((tx) => _within(tx.createdAt, range)).toList();
    final totalSales = transactions.fold<int>(
        0, (total, transaction) => total + transaction.grandTotal);
    final receivables = transactions.fold<int>(
        0, (total, transaction) => total + transaction.remainingBalance);
    final paymentsReceived = allTransactions.fold<int>(0, (total, transaction) {
      return total +
          transaction.payments
              .where((payment) => _within(payment.paidAt, range))
              .fold<int>(0, (sum, payment) => sum + payment.amount);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hari ini'),
                selected: _period == _ReportPeriod.today,
                onSelected: (_) =>
                    setState(() => _period = _ReportPeriod.today),
              ),
              ChoiceChip(
                label: const Text('Bulan ini'),
                selected: _period == _ReportPeriod.month,
                onSelected: (_) =>
                    setState(() => _period = _ReportPeriod.month),
              ),
              ChoiceChip(
                label: Text(_period == _ReportPeriod.range &&
                        _dateRange != null
                    ? '${DateFormat('dd/MM').format(_dateRange!.start)} - '
                        '${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'
                    : 'Rentang tanggal'),
                selected: _period == _ReportPeriod.range,
                onSelected: (_) => _selectRange(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _metric('Jumlah transaksi', '${transactions.length}'),
              _metric('Total penjualan', formatRupiah(totalSales)),
              _metric(
                  'Pembayaran diterima (tgl bayar)',
                  formatRupiah(paymentsReceived)),
              _metric(
                  'Piutang transaksi periode (saldo saat ini)',
                  formatRupiah(receivables)),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Pembayaran diterima dihitung dari tanggal pembayaran dan '
                  'dapat berasal dari transaksi sebelum periode ini. '
                  'Tabel menampilkan transaksi berdasarkan tanggal dibuat.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () => _exportPdf(
              transactions,
              totalSales,
              paymentsReceived,
              receivables,
              range,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Ekspor PDF'),
          ),
        ),
        const Divider(height: 24),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('Tidak ada transaksi pada periode ini.'))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      title: Text(transaction.transactionNumber),
                      subtitle: Text(
                          '${transaction.customer.name} • '
                          '${DateFormat('dd/MM/yyyy').format(transaction.createdAt)}'),
                      trailing: Text(formatRupiah(transaction.grandTotal)),
                      onTap: () =>
                          context.push('/transactions/${transaction.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) => Card(
        child: ListTile(
          title: Text(label),
          trailing:
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  Future<void> _exportPdf(
    List<Transaction> transactions,
    int totalSales,
    int paymentsReceived,
    int receivables,
    DateTimeRange range,
  ) async {
    try {
      final rows = <List<String>>[
        ['Nomor', 'Tanggal', 'Customer', 'Total', 'Dibayar', 'Sisa', 'Status'],
        ...transactions.map((transaction) => [
              transaction.transactionNumber,
              DateFormat('dd/MM/yyyy').format(transaction.createdAt),
              transaction.customer.name,
              formatRupiah(transaction.grandTotal),
              formatRupiah(transaction.totalPaid),
              formatRupiah(transaction.remainingBalance),
              transaction.status.label,
            ]),
      ];
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Header(
            level: 0,
            child: pw.Text('Laporan Transaksi GaragePOS'),
          ),
          pw.Text(
            'Periode: ${DateFormat('dd/MM/yyyy').format(range.start)} - '
            '${DateFormat('dd/MM/yyyy').format(range.end)}',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Jumlah transaksi: ${transactions.length}'),
          pw.Text('Total penjualan: ${formatRupiah(totalSales)}'),
          pw.Text(
              'Pembayaran diterima (tanggal pembayaran): ${formatRupiah(paymentsReceived)}'),
          pw.Text(
              'Piutang transaksi periode (saldo saat ini): ${formatRupiah(receivables)}'),
          pw.Text(
            'Pembayaran diterima mengikuti tanggal pembayaran, dapat berasal '
            'dari transaksi sebelum periode. Tabel mengikuti tanggal transaksi.',
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: rows.asMap().entries.map((entry) {
              final row = entry.value;
              final isHeader = entry.key == 0;
              return pw.TableRow(
                children: row
                    .map(
                      (cell) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          cell,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: isHeader
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            }).toList(),
          ),
        ],
      ));
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'laporan_transaksi_$stamp.pdf',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengekspor PDF: $error'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}
