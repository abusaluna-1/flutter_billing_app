import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/widgets/input_label.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_item.dart';
import '../../domain/service_validator.dart';
import '../bloc/service_bloc.dart';

class ServiceFormPage extends StatefulWidget {
  /// null = jasa baru.
  final ServiceItem? service;
  const ServiceFormPage({super.key, this.service});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  late final TextEditingController _note;
  String? _categoryId;
  bool _isActive = true;
  bool _submitting = false;

  bool get _isEdit => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _name = TextEditingController(text: s?.name ?? '');
    _price = TextEditingController(text: s?.defaultPrice?.toString() ?? '');
    _unit = TextEditingController(text: s?.unit ?? ServiceItem.defaultUnit);
    _note = TextEditingController(text: s?.note ?? '');
    _categoryId = s?.categoryId;
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _unit.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit(List<ServiceCategory> categories) {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.service;
    final item = ServiceItem(
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      categoryId: _categoryId ?? '',
      defaultPrice: ServiceValidator.parsePrice(_price.text),
      unit: _unit.text.trim().isEmpty
          ? ServiceItem.defaultUnit
          : _unit.text.trim(),
      note: _note.text.trim(),
      isActive: _isActive,
    );

    setState(() => _submitting = true);
    final bloc = context.read<ServiceBloc>();
    bloc.add(_isEdit ? UpdateServiceEvent(item) : AddServiceEvent(item));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServiceBloc, ServiceState>(
      listenWhen: (a, b) => a.feedbackSeq != b.feedbackSeq,
      listener: (context, state) {
        if (!_submitting) return;
        if (state.isError) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.message ?? 'Gagal menyimpan jasa.'),
              backgroundColor: Colors.red,
            ));
        } else {
          context.pop(true);
        }
      },
      builder: (context, state) {
        final categories = state.categories;
        // Kategori tersimpan yang sudah tidak ada tidak dipilih otomatis.
        final validSelection = categories.any((c) => c.id == _categoryId);
        return Scaffold(
          appBar: AppBar(title: Text(_isEdit ? 'Ubah Jasa' : 'Jasa Baru')),
          body: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const InputLabel(text: 'Nama jasa'),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            hintText: 'Contoh: Bubut poros'),
                        validator: ServiceValidator.name,
                      ),
                      const SizedBox(height: 16),
                      const InputLabel(text: 'Kategori'),
                      FormField<String>(
                        initialValue: validSelection ? _categoryId : null,
                        validator: (_) =>
                            ServiceValidator.categoryId(
                                validSelection ? _categoryId : null),
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final c in categories)
                                  ChoiceChip(
                                    label: Text(c.name),
                                    selected: _categoryId == c.id,
                                    onSelected: (_) {
                                      setState(() => _categoryId = c.id);
                                      field.didChange(c.id);
                                    },
                                  ),
                              ],
                            ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(field.errorText!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const InputLabel(text: 'Harga standar (boleh kosong)'),
                      TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          hintText: 'Kosongkan jika harga ditentukan saat kasir',
                        ),
                        validator: ServiceValidator.priceText,
                      ),
                      const SizedBox(height: 16),
                      const InputLabel(text: 'Satuan'),
                      TextFormField(
                        controller: _unit,
                        decoration:
                            const InputDecoration(hintText: 'Pekerjaan'),
                        validator: ServiceValidator.unit,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final u in ServiceItem.unitSuggestions)
                            ActionChip(
                              label: Text(u),
                              onPressed: () => setState(() => _unit.text = u),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const InputLabel(text: 'Catatan (opsional)'),
                      TextFormField(
                        controller: _note,
                        maxLines: 2,
                        validator: ServiceValidator.note,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Jasa aktif'),
                        subtitle: const Text(
                            'Jasa nonaktif tidak muncul saat transaksi'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: PrimaryButton(
                  label: 'Simpan',
                  isLoading: _submitting,
                  onPressed: () => _submit(categories),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
