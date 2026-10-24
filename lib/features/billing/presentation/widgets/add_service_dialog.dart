import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../product/domain/entities/product.dart';

/// Dialog untuk menambah item JASA secara manual ke transaksi.
/// Mengembalikan [Product] dengan `isService: true` (tanpa barcode & stok),
/// atau null jika dibatalkan. Hasilnya tidak disimpan ke database produk.
Future<Product?> showAddServiceDialog(BuildContext context) {
  return showDialog<Product>(
    context: context,
    builder: (_) => const _AddServiceDialog(),
  );
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog();

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Product(
        // id unik supaya dua jasa dengan nama sama tetap jadi baris terpisah.
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        barcode: '',
        price: double.parse(_priceController.text.trim()),
        stock: 0,
        isService: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Jasa'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama jasa',
                hintText: 'mis. Korter blok',
              ),
              validator: AppValidators.required('Nama jasa wajib diisi'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Harga',
                hintText: 'mis. 150000',
              ),
              validator: AppValidators.price,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}
