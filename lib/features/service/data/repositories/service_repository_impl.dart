import 'package:fpdart/fpdart.dart';
import 'package:hive/hive.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/load_result.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_item.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/service_failures.dart';
import '../../domain/service_validator.dart';
import '../models/service_category_model.dart';
import '../models/service_model.dart';

/// Penyimpanan master jasa & kategori di Hive.
///
/// Setiap data disimpan sebagai teks JSON dengan key = id, di box terpisah
/// dari produk. Prinsip keamanan data:
/// - Data yang tidak terbaca (JSON rusak/isi tidak valid) DILEWATI saat
///   membaca, tidak pernah dihapus atau ditimpa otomatis.
/// - Kesalahan penyimpanan dikembalikan sebagai `Left`, tidak dilempar.
class ServiceRepositoryImpl implements ServiceRepository {
  /// Penanda bahwa kategori awal sudah pernah diisi. Dengan penanda ini,
  /// kategori awal yang sengaja dihapus pengguna tidak muncul lagi.
  static const String seedFlagKey = 'service_categories_seeded_v1';

  final Box<String>? _serviceBox;
  final Box<String>? _categoryBox;
  final Box? _settingsBox;

  /// Parameter box hanya untuk pengujian; aplikasi memakai box dari
  /// [HiveDatabase].
  ServiceRepositoryImpl({
    Box<String>? serviceBox,
    Box<String>? categoryBox,
    Box? settingsBox,
  })  : _serviceBox = serviceBox,
        _categoryBox = categoryBox,
        _settingsBox = settingsBox;

  Box<String> get _services => _serviceBox ?? HiveDatabase.serviceBox;
  Box<String> get _categories =>
      _categoryBox ?? HiveDatabase.serviceCategoryBox;
  Box get _settings => _settingsBox ?? HiveDatabase.settingsBox;

  // ------------------------------------------------------------ Pembacaan

  LoadResult<ServiceItem> _readServices() {
    final items = <ServiceItem>[];
    var skipped = 0;
    for (final raw in _services.values) {
      try {
        items.add(ServiceModel.decode(raw));
      } catch (_) {
        skipped++;
      }
    }
    items.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return LoadResult<ServiceItem>(items: items, skipped: skipped);
  }

  LoadResult<ServiceCategory> _readCategories() {
    final items = <ServiceCategory>[];
    var skipped = 0;
    for (final raw in _categories.values) {
      try {
        items.add(ServiceCategoryModel.decode(raw));
      } catch (_) {
        skipped++;
      }
    }

    // Urutan: kategori awal (sesuai urutan awal), kategori buatan sendiri
    // (A-Z), lalu "Lainnya" paling akhir.
    int rank(ServiceCategory c) {
      if (c.id == ServiceCategory.lainnyaId) return 2;
      return ServiceCategory.defaults.any((d) => d.id == c.id) ? 0 : 1;
    }

    items.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      if (rank(a) == 0) {
        final ia = ServiceCategory.defaults.indexWhere((d) => d.id == a.id);
        final ib = ServiceCategory.defaults.indexWhere((d) => d.id == b.id);
        return ia.compareTo(ib);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return LoadResult<ServiceCategory>(items: items, skipped: skipped);
  }

  bool _categoryExists(String id) {
    final raw = _categories.get(id);
    if (raw == null) return false;
    try {
      ServiceCategoryModel.decode(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _categoryNameTaken(String name, {String? exceptId}) {
    final wanted = name.trim().toLowerCase();
    for (final c in _readCategories().items) {
      if (c.id == exceptId) continue;
      if (c.name.trim().toLowerCase() == wanted) return true;
    }
    return false;
  }

  // ---------------------------------------------------------- Kategori awal

  /// Mengisi kategori awal SEKALI. Idempoten: ID kategori awal tetap, dan
  /// kategori yang sudah ada (walau isinya rusak) tidak pernah ditimpa.
  Future<void> _ensureSeeded() async {
    if (_settings.get(seedFlagKey) == true) return;
    for (final c in ServiceCategory.defaults) {
      if (!_categories.containsKey(c.id)) {
        await _categories.put(c.id, ServiceCategoryModel.encode(c));
      }
    }
    await _settings.put(seedFlagKey, true);
  }

  ServiceItem _normalized(ServiceItem s) {
    return ServiceItem(
      id: s.id.trim(),
      name: s.name.trim(),
      categoryId: s.categoryId.trim(),
      defaultPrice: s.defaultPrice,
      unit: s.unit.trim(),
      note: s.note.trim(),
      isActive: s.isActive,
    );
  }

  // ------------------------------------------------------------------- Jasa

  @override
  Future<Either<Failure, LoadResult<ServiceItem>>> getServices() async {
    try {
      await _ensureSeeded();
      return Right(_readServices());
    } catch (_) {
      return Left(CacheFailure('Gagal membaca data jasa.'));
    }
  }

  @override
  Future<Either<Failure, void>> addService(ServiceItem service) async {
    final error = ServiceValidator.service(service);
    if (error != null) return Left(ServiceValidationFailure(error));

    try {
      await _ensureSeeded();
      final item = _normalized(service);
      if (_services.containsKey(item.id)) {
        return Left(ServiceValidationFailure('ID jasa sudah dipakai.'));
      }
      if (!_categoryExists(item.categoryId)) {
        return Left(ServiceValidationFailure('Kategori tidak valid.'));
      }
      await _services.put(item.id, ServiceModel.encode(item));
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menyimpan jasa. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateService(ServiceItem service) async {
    final error = ServiceValidator.service(service);
    if (error != null) return Left(ServiceValidationFailure(error));

    try {
      await _ensureSeeded();
      final item = _normalized(service);
      if (!_services.containsKey(item.id)) {
        return Left(ServiceValidationFailure('Jasa tidak ditemukan.'));
      }
      if (!_categoryExists(item.categoryId)) {
        return Left(ServiceValidationFailure('Kategori tidak valid.'));
      }
      await _services.put(item.id, ServiceModel.encode(item));
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menyimpan perubahan jasa. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> setServiceActive(
      String id, bool isActive) async {
    try {
      final raw = _services.get(id);
      if (raw == null) {
        return Left(ServiceValidationFailure('Jasa tidak ditemukan.'));
      }
      ServiceItem? current;
      try {
        current = ServiceModel.decode(raw);
      } catch (_) {
        current = null;
      }
      if (current == null) {
        return Left(
            CacheFailure('Data jasa rusak sehingga tidak dapat diubah.'));
      }
      await _services.put(
        id,
        ServiceModel.encode(current.copyWith(isActive: isActive)),
      );
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal mengubah status jasa. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteService(String id) async {
    try {
      if (!_services.containsKey(id)) {
        return Left(ServiceValidationFailure('Jasa tidak ditemukan.'));
      }
      await _services.delete(id);
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menghapus jasa. Coba lagi.'));
    }
  }

  // --------------------------------------------------------------- Kategori

  @override
  Future<Either<Failure, LoadResult<ServiceCategory>>> getCategories() async {
    try {
      await _ensureSeeded();
      return Right(_readCategories());
    } catch (_) {
      return Left(CacheFailure('Gagal membaca data kategori.'));
    }
  }

  @override
  Future<Either<Failure, void>> addCategory(ServiceCategory category) async {
    final error = ServiceValidator.categoryName(category.name);
    if (error != null) return Left(ServiceValidationFailure(error));
    if (category.id.trim().isEmpty) {
      return Left(ServiceValidationFailure('ID kategori tidak valid.'));
    }

    try {
      await _ensureSeeded();
      final id = category.id.trim();
      final name = category.name.trim();
      if (_categories.containsKey(id)) {
        return Left(ServiceValidationFailure('ID kategori sudah dipakai.'));
      }
      if (_categoryNameTaken(name)) {
        return Left(ServiceValidationFailure('Kategori "$name" sudah ada.'));
      }
      await _categories.put(
        id,
        ServiceCategoryModel.encode(ServiceCategory(id: id, name: name)),
      );
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menyimpan kategori. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateCategory(
      ServiceCategory category) async {
    final error = ServiceValidator.categoryName(category.name);
    if (error != null) return Left(ServiceValidationFailure(error));

    try {
      await _ensureSeeded();
      final id = category.id.trim();
      final name = category.name.trim();
      if (!_categories.containsKey(id)) {
        return Left(ServiceValidationFailure('Kategori tidak ditemukan.'));
      }
      if (_categoryNameTaken(name, exceptId: id)) {
        return Left(ServiceValidationFailure('Kategori "$name" sudah ada.'));
      }
      await _categories.put(
        id,
        ServiceCategoryModel.encode(ServiceCategory(id: id, name: name)),
      );
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menyimpan kategori. Coba lagi.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    if (id == ServiceCategory.lainnyaId) {
      return Left(
          ServiceValidationFailure('Kategori "Lainnya" tidak dapat dihapus.'));
    }

    try {
      if (!_categories.containsKey(id)) {
        return Left(ServiceValidationFailure('Kategori tidak ditemukan.'));
      }
      final inUse =
          _readServices().items.where((s) => s.categoryId == id).length;
      if (inUse > 0) {
        return Left(ServiceValidationFailure(
          'Kategori masih dipakai $inUse jasa. '
          'Pindahkan jasa tersebut ke kategori lain terlebih dahulu.',
        ));
      }
      await _categories.delete(id);
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure('Gagal menghapus kategori. Coba lagi.'));
    }
  }
}
