import 'dart:convert';

import '../../domain/entities/service_category.dart';

/// Bentuk penyimpanan [ServiceCategory] sebagai JSON (String di Hive).
class ServiceCategoryModel extends ServiceCategory {
  static const int schemaVersion = 1;

  const ServiceCategoryModel({required super.id, required super.name});

  factory ServiceCategoryModel.fromEntity(ServiceCategory c) {
    return ServiceCategoryModel(id: c.id, name: c.name);
  }

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('ID kategori tidak valid');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Nama kategori tidak valid');
    }
    return ServiceCategoryModel(id: id, name: name);
  }

  Map<String, dynamic> toJson() {
    return {'schema': schemaVersion, 'id': id, 'name': name};
  }

  ServiceCategory toEntity() => ServiceCategory(id: id, name: name);

  static String encode(ServiceCategory c) {
    return jsonEncode(ServiceCategoryModel.fromEntity(c).toJson());
  }

  static ServiceCategory decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bentuk data kategori tidak valid');
    }
    return ServiceCategoryModel.fromJson(decoded).toEntity();
  }
}
