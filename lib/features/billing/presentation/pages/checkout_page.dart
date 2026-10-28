import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/utils/rupiah.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _adminName = TextEditingController();
  final _amountPaid = TextEditingController(text: '0');
  String _paymentMethod = 'Tunai';

  @override
  void initState() {
    super.initState();
    _adminName.text =
        HiveDatabase.settingsBox.get('active_admin_name', defaultValue: '');
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _adminName.dispose();
    _amountPaid.dispose();
    super.dispose();
  }

  int get _paidAmount =>
      int.tryParse(_amountPaid.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.go('/'),
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listenWhen: (previous, current) =>
              previous.error != current.error ||
              previous.completedTransactionNumber !=
                  current.completedTransactionNumber,
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ));
            }
            if (state.completedTransactionNumber != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Transaksi ${state.completedTransactionNumber} tersimpan'),
                backgroundColor: Colors.green,
              ));
              context.go('/');
            }
          },
          builder: (context, state) {
            final total = state.checkoutTotalAmount;
            final enteredAmount = _paidAmount;
            final paid = enteredAmount < 0
                ? 0
                : enteredAmount > total
                    ? total
                    : enteredAmount;
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _sectionTitle('Item Transaksi'),
                        ...state.cartItems.map((item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.product.name),
                              subtitle: Text(
                                  '${item.quantity} x ${formatRupiah(item.product.price.round())}'),
                              trailing: Text(
                                  formatRupiah(item.total.round()),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            )),
                        const Divider(height: 28),
                        _sectionTitle('Customer'),
                        TextFormField(
                          controller: _customerName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Nama customer *'),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Nama customer wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Nomor HP (opsional)'),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Admin / Kasir'),
                        TextFormField(
                          controller: _adminName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Nama admin/kasir *'),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Nama admin/kasir wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Pembayaran'),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                              labelText: 'Metode pembayaran'),
                          items: const [
                            'Tunai',
                            'Transfer',
                            'QRIS',
                            'Kartu',
                          ]
                              .map((method) => DropdownMenuItem(
                                    value: method,
                                    child: Text(method),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _paymentMethod = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountPaid,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Nominal dibayar (Rp)',
                            suffixIcon: TextButton(
                              onPressed: () {
                                _amountPaid.text = '$total';
                                setState(() {});
                              },
                              child: const Text('Isi Lunas'),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final amount = int.tryParse(value ?? '');
                            if (amount == null || amount < 0 || amount > total) {
                              return 'Masukkan nominal antara Rp0 dan total transaksi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _amountRow('Total transaksi', total),
                        _amountRow('Dibayar', paid),
                        _amountRow('Sisa pembayaran', total - paid, bold: true),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PrimaryButton(
                        onPressed: state.isSavingCheckout
                            ? null
                            : () {
                                if (!_formKey.currentState!.validate()) return;
                                context.read<BillingBloc>().add(
                                      CompleteCheckoutEvent(
                                        customerName: _customerName.text.trim(),
                                        customerPhone:
                                            _customerPhone.text.trim(),
                                        adminName: _adminName.text.trim(),
                                        amountPaid: _paidAmount,
                                        paymentMethod: _paymentMethod,
                                      ),
                                    );
                              },
                        label: state.isSavingCheckout
                            ? 'Menyimpan...'
                            : 'Simpan Transaksi',
                        icon: Icons.save,
                        isLoading: state.isSavingCheckout,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _amountRow(String title, int amount, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(formatRupiah(amount),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
}
