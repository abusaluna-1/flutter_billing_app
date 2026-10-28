import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/rupiah.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../service/domain/entities/service_item.dart';
import '../../../service/presentation/bloc/service_bloc.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'Semua';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode == null || barcode.isEmpty) return;
    final match = products.where((product) => product.barcode == barcode).firstOrNull;
    _searchController.text = match?.name ?? barcode;
  }

  Product _asProduct(ServiceItem service) => Product(
        id: service.id,
        name: service.name,
        barcode: '',
        price: (service.defaultPrice ?? 0).toDouble(),
        isService: true,
      );

  Future<void> _showAddOptions() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Tambah Produk'),
              onTap: () => Navigator.pop(context, 'product'),
            ),
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Tambah Jasa'),
              onTap: () => Navigator.pop(context, 'service'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;
    await context.push(selection == 'product' ? '/products/add' : '/services/form');
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey[100]!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Produk & Jasa',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau barcode',
                            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Semua', 'Produk', 'Jasa']
                        .map((filter) => ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) => setState(() => _filter = filter),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.message != null &&
                    (state.status == ProductStatus.success ||
                        state.status == ProductStatus.error)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(state.message!),
                    backgroundColor: state.status == ProductStatus.error
                        ? Colors.red
                        : Colors.green,
                  ));
                }
              },
              builder: (context, productState) =>
                  BlocBuilder<ServiceBloc, ServiceState>(
                builder: (context, serviceState) {
                  if (productState.status == ProductStatus.loading &&
                      productState.products.isEmpty ||
                      serviceState.status == ServiceStatus.loading &&
                          serviceState.services.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = _filter == 'Jasa'
                      ? <Product>[]
                      : productState.products;
                  final services = _filter == 'Produk'
                      ? <Product>[]
                      : serviceState.services
                          .where((service) => service.isActive)
                          .map(_asProduct)
                          .toList();
                  final items = [...products, ...services].where((item) {
                    return item.name.toLowerCase().contains(_searchQuery) ||
                        item.barcode.toLowerCase().contains(_searchQuery);
                  }).toList();
                  if (items.isEmpty) {
                    if (productState.status == ProductStatus.error &&
                        productState.products.isEmpty &&
                        serviceState.services.isEmpty) {
                      return Center(child: Text('Error: ${productState.message}'));
                    }
                    return const Center(child: Text('Tidak ada item yang cocok.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.isService ? 'Jasa' : 'Produk'}'
                                    '${item.isService ? '' : ' • Stok ${item.stock}'}'
                                    ' • ${formatRupiah(item.price.round())}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: AppTheme.primaryColor),
                              onPressed: () => item.isService
                                  ? context.push('/services/form',
                                      extra: serviceState.services
                                          .firstWhere((s) => s.id == item.id))
                                  : context.push('/products/edit/${item.id}',
                                      extra: item),
                            ),
                            if (!item.isService)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () =>
                                    _confirmDelete(context, item),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProductBloc>().add(DeleteProduct(product.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
