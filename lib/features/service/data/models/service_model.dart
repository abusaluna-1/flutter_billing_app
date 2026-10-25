import 'dart:convert';

import '../../domain/entities/service_item.dart';

/// Bentuk penyimpanan [ServiceItem] sebagai JSON (disimpan sebagai String di Hive).
///
/// - Harga disimpan sebagai bilangan bulat Rupiah (bukan double).
/// - `schema` dicatat supaya format bisa dimigrasi di masa depan.
/// - Field opsional yang hilang diberi nilai bawaan; field wajib yang rusak
///   melempar [FormatException] (data itu dilewati, tidak dihapus).
class ServiceModel extends ServiceItem {
  static const int schemaVersion = 1;

  const ServiceModel({
    required super.id,
    required super.name,
    required super.categoryId,
    super.defaultPrice,
    required super.unit,
    required super.note,
    required super.isActive,
  });

  factory ServiceModel.fromEntity(ServiceItem s) {
    return ServiceModel(
      id: s.id,
      name: s.name,
      categoryId: s.categoryId,
      defaultPrice: s.defaultPrice,
      unit: s.unit,
      note: s.note,
      isActive: s.isActive,
    );
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final categoryId = json['categoryId'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('ID jasa tidak valid');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Nama jasa tidak valid');
    }
    if (categoryId is! String || categoryId.trim().isEmpty) {
      throw const FormatException('Kategori jasa tidak valid');
    }

    final rawPrice = json['defaultPrice'];
    int? price;
    if (rawPrice != null) {
      if (rawPrice is! int || rawPrice < 0) {
        throw const FormatException('Harga jasa tidak valid');
      }
      price = rawPrice;
    }

    final rawUnit = json['unit'];
    final rawNote = json['note'];
    final rawActive = json['isActive'];

    return ServiceModel(
      id: id,
      name: name,
      categoryId: categoryId,
      defaultPrice: price,
      unit: (rawUnit is String && rawUnit.trim().isNotEmpty)
          ? rawUnit
          : ServiceItem.defaultUnit,
      note: rawNote is String ? rawNote : '',
      isActive: rawActive is bool ? rawActive : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema': schemaVersion,
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'defaultPrice': defaultPrice,
      'unit': unit,
      'note': note,
      'isActive': isActive,
    };
  }

  /// Entity murni (bukan subclass), supaya perbandingan Equatable konsisten.
  ServiceItem toEntity() {
    return ServiceItem(
      id: id,
      name: name,
      categoryId: categoryId,
      defaultPrice: defaultPrice,
      unit: unit,
      note: note,
      isActive: isActive,
    );
  }

  /// Entity -> teks JSON siap disimpan.
  static String encode(ServiceItem s) {
    return jsonEncode(ServiceModel.fromEntity(s).toJson());
  }

  /// Teks JSON -> entity. Melempar [FormatException] jika rusak/tidak valid.
  static ServiceItem decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bentuk data jasa tidak valid');
    }
    return ServiceModel.fromJson(decoded).toEntity();
  }
}
