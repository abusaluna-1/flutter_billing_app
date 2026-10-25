import 'package:equatable/equatable.dart';

/// Master data jasa (bukan sparepart): tanpa barcode, tanpa stok.
class ServiceItem extends Equatable {
  final String id;
  final String name;
  final String categoryId;

  /// Harga standar dalam Rupiah bulat (tanpa pecahan). `null` = belum ditentukan.
  final int? defaultPrice;

  /// Satuan jasa, mis. Pekerjaan, Unit, Lubang, Set, Pasang.
  final String unit;
  final String note;
  final bool isActive;

  static const String defaultUnit = 'Pekerjaan';
  static const List<String> unitSuggestions = [
    'Pekerjaan',
    'Unit',
    'Lubang',
    'Set',
    'Pasang',
  ];

  const ServiceItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.defaultPrice,
    this.unit = defaultUnit,
    this.note = '',
    this.isActive = true,
  });

  ServiceItem copyWith({
    String? name,
    String? categoryId,
    int? defaultPrice,
    bool clearPrice = false,
    String? unit,
    String? note,
    bool? isActive,
  }) {
    return ServiceItem(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      defaultPrice: clearPrice ? null : (defaultPrice ?? this.defaultPrice),
      unit: unit ?? this.unit,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, categoryId, defaultPrice, unit, note, isActive];
}
