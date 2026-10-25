import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/rupiah.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_item.dart';
import '../bloc/service_bloc.dart';

enum _StatusFilter { semua, aktif, nonaktif }

class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  String _query = '';
  String? _categoryId; // null = semua kategori
  _StatusFilter _status = _StatusFilter.semua;

  String _categoryName(List<ServiceCategory> categories, String id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return 'Tanpa kategori';
  }

  List<ServiceItem> _filter(List<ServiceItem> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (_categoryId != null && s.categoryId != _categoryId) return false;
      if (_status == _StatusFilter.aktif && !s.isActive) return false;
      if (_status == _StatusFilter.nonaktif && s.isActive) return false;
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  Future<void> _openForm([ServiceItem? service]) async {
    await context.push<bool>('/services/form', extra: service);
  }

  Future<void> _confirmDelete(ServiceItem service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus jasa?'),
        content: Text(
          '"${service.name}" akan dihapus permanen dari daftar jasa. '
          'Jika hanya ingin menyembunyikan, gunakan Nonaktifkan.',
        ),
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
    if (ok == true && mounted) {
      context.read<ServiceBloc>().add(DeleteServiceEvent(service.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ServiceBloc, ServiceState>(
      listenWhen: (a, b) => a.feedbackSeq != b.feedbackSeq,
      listener: (context, state) {
        // Pesan hanya ditampilkan bila halaman ini yang sedang terlihat.
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
        final items = _filter(state.services);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Daftar Jasa'),
            actions: [
              PopupMenuButton<_StatusFilter>(
                tooltip: 'Filter status',
                icon: const Icon(Icons.filter_list),
                initialValue: _status,
                onSelected: (v) => setState(() => _status = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: _StatusFilter.semua, child: Text('Semua status')),
                  PopupMenuItem(
                      value: _StatusFilter.aktif, child: Text('Aktif saja')),
                  PopupMenuItem(
                      value: _StatusFilter.nonaktif,
                      child: Text('Nonaktif saja')),
                ],
              ),
              IconButton(
                tooltip: 'Kelola kategori',
                icon: const Icon(Icons.category_outlined),
                onPressed: () => context.push('/services/categories'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Jasa Baru'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari nama jasa',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                    ),
                    for (final c in state.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.corruptServiceCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${state.corruptServiceCount} data jasa tidak terbaca '
                    'dan dilewati. Data asli tidak dihapus.',
                  ),
                ),
              Expanded(child: _buildBody(state, items)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ServiceState state, List<ServiceItem> items) {
    if (state.status == ServiceStatus.initial ||
        state.status == ServiceStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == ServiceStatus.error && state.services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat daftar jasa.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  context.read<ServiceBloc>().add(const LoadServices()),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      final empty = state.services.isEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            empty
                ? 'Belum ada jasa. Ketuk "Jasa Baru" untuk menambah.'
                : 'Tidak ada jasa yang cocok dengan pencarian/filter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i];
        final price = s.defaultPrice == null
            ? 'Harga belum ditentukan'
            : '${formatRupiah(s.defaultPrice!)} / ${s.unit}';
        return Opacity(
          opacity: s.isActive ? 1 : 0.55,
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _openForm(s),
              title: Text(s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_categoryName(state.categories, s.categoryId)} • $price'
                '${s.isActive ? '' : ' • Nonaktif'}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  final bloc = context.read<ServiceBloc>();
                  if (v == 'ubah') {
                    _openForm(s);
                  } else if (v == 'toggle') {
                    bloc.add(ToggleServiceActiveEvent(
                        id: s.id, isActive: !s.isActive));
                  } else if (v == 'hapus') {
                    _confirmDelete(s);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'ubah', child: Text('Ubah')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(s.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                  const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
