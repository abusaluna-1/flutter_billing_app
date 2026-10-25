import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/service_category.dart';
import '../../domain/service_validator.dart';
import '../bloc/service_bloc.dart';

class ServiceCategoryPage extends StatelessWidget {
  const ServiceCategoryPage({super.key});

  Future<void> _showEditor(BuildContext context,
      {ServiceCategory? category}) async {
    final controller = TextEditingController(text: category?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final bloc = context.read<ServiceBloc>();

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category == null ? 'Kategori Baru' : 'Ubah Nama Kategori',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nama kategori'),
                validator: ServiceValidator.categoryName,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(ctx, controller.text.trim());
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (name == null) return;
    if (category == null) {
      bloc.add(AddCategoryEvent(
          ServiceCategory(id: 'kategori-${const Uuid().v4()}', name: name)));
    } else {
      bloc.add(UpdateCategoryEvent(category.copyWith(name: name)));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ServiceCategory category) async {
    final bloc = context.read<ServiceBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(DeleteCategoryEvent(category.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServiceBloc, ServiceState>(
      listenWhen: (a, b) => a.feedbackSeq != b.feedbackSeq,
      listener: (context, state) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (!isCurrent || state.message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(state.message!),
            backgroundColor: state.isError ? Colors.red : Colors.green,
          ));
      },
      builder: (context, state) {
        int countFor(String id) =>
            state.services.where((s) => s.categoryId == id).length;
        return Scaffold(
          appBar: AppBar(title: const Text('Kategori Jasa')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Kategori Baru'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (state.corruptCategoryCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.corruptCategoryCount} data kategori tidak '
                    'terbaca dan dilewati. Data asli tidak dihapus.',
                  ),
                ),
              for (final c in state.categories)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.name),
                    subtitle: Text('${countFor(c.id)} jasa'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ubah nama',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditor(context, category: c),
                        ),
                        if (c.id != ServiceCategory.lainnyaId)
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _confirmDelete(context, c),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
