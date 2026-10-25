import 'package:equatable/equatable.dart';

/// Kategori jasa, mis. Korter, Bubut, Frais.
class ServiceCategory extends Equatable {
  final String id;
  final String name;

  const ServiceCategory({required this.id, required this.name});

  /// ID kategori "Lainnya". Kategori ini tidak boleh dihapus.
  static const String lainnyaId = 'kategori-lainnya';

  /// Kategori awal. ID-nya tetap (bukan acak) supaya pengisian awal
  /// tidak pernah membuat duplikat.
  static const List<ServiceCategory> defaults = [
    ServiceCategory(id: 'kategori-korter', name: 'Korter'),
    ServiceCategory(id: 'kategori-bubut', name: 'Bubut'),
    ServiceCategory(id: 'kategori-frais', name: 'Frais'),
    ServiceCategory(id: 'kategori-press', name: 'Press'),
    ServiceCategory(id: 'kategori-las', name: 'Las'),
    ServiceCategory(id: lainnyaId, name: 'Lainnya'),
  ];

  ServiceCategory copyWith({String? name}) {
    return ServiceCategory(id: id, name: name ?? this.name);
  }

  @override
  List<Object?> get props => [id, name];
}
