import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock; // Optional implementation detail

  /// true = item JASA (tanpa barcode & tanpa stok), ditambahkan manual ke
  /// transaksi. Sengaja tidak disimpan ke Hive: jasa hanya hidup di cart.
  /// Produk/sparepart tetap `false` (default), perilakunya tidak berubah.
  final bool isService;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.isService = false,
  });

  @override
  List<Object?> get props => [id, name, barcode, price, stock, isService];
}
