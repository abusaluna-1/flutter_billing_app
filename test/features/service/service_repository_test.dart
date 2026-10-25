import 'dart:io';

import 'package:billing_app/features/service/data/models/service_model.dart';
import 'package:billing_app/features/service/data/repositories/service_repository_impl.dart';
import 'package:billing_app/features/service/domain/entities/service_category.dart';
import 'package:billing_app/features/service/domain/entities/service_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;
  late Box<String> serviceBox;
  late Box<String> categoryBox;
  late Box settingsBox;
  late ServiceRepositoryImpl repo;

  ServiceRepositoryImpl newRepo() => ServiceRepositoryImpl(
        serviceBox: serviceBox,
        categoryBox: categoryBox,
        settingsBox: settingsBox,
      );

  const bubut = 'kategori-bubut';

  ServiceItem svc(String id,
          {String name = 'Bubut poros', int? price = 150000, String? cat}) =>
      ServiceItem(
        id: id,
        name: name,
        categoryId: cat ?? bubut,
        defaultPrice: price,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('garagepos_test_');
    Hive.init(dir.path);
    serviceBox = await Hive.openBox<String>('services');
    categoryBox = await Hive.openBox<String>('categories');
    settingsBox = await Hive.openBox('settings_test');
    repo = newRepo();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('simpan dan baca jasa', () async {
    final r = await repo.addService(svc('s1'));
    expect(r.isRight(), true);

    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.length, 1);
    expect(list.items.first.name, 'Bubut poros');
    expect(list.items.first.defaultPrice, 150000);
    expect(list.skipped, 0);
  });

  test('data tetap ada setelah repository dibuat ulang', () async {
    await repo.addService(svc('s1'));
    final again = newRepo();
    final list = (await again.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.map((e) => e.id), ['s1']);
  });

  test('ubah jasa', () async {
    await repo.addService(svc('s1'));
    final r = await repo.updateService(svc('s1', name: 'Bubut as', price: 200000));
    expect(r.isRight(), true);
    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.single.name, 'Bubut as');
    expect(list.items.single.defaultPrice, 200000);
  });

  test('ubah jasa yang tidak ada ditolak', () async {
    final r = await repo.updateService(svc('tidak-ada'));
    expect(r.isLeft(), true);
  });

  test('nonaktifkan dan aktifkan kembali', () async {
    await repo.addService(svc('s1'));
    expect((await repo.setServiceActive('s1', false)).isRight(), true);
    var list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.single.isActive, false);

    expect((await repo.setServiceActive('s1', true)).isRight(), true);
    list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.single.isActive, true);
  });

  test('hapus jasa', () async {
    await repo.addService(svc('s1'));
    expect((await repo.deleteService('s1')).isRight(), true);
    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items, isEmpty);
    expect((await repo.deleteService('s1')).isLeft(), true);
  });

  test('harga kosong diperbolehkan dan tetap kosong', () async {
    expect((await repo.addService(svc('s1', price: null))).isRight(), true);
    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.single.defaultPrice, isNull);
  });

  test('harga negatif ditolak dan tidak tersimpan', () async {
    final r = await repo.addService(svc('s1', price: -1));
    expect(r.isLeft(), true);
    expect(serviceBox.isEmpty, true);
  });

  test('nama kosong ditolak', () async {
    final r = await repo.addService(svc('s1', name: '  '));
    expect(r.isLeft(), true);
    expect(serviceBox.isEmpty, true);
  });

  test('kategori tidak ada ditolak', () async {
    final r = await repo.addService(svc('s1', cat: 'kategori-hantu'));
    expect(r.isLeft(), true);
  });

  test('ID jasa harus unik', () async {
    await repo.addService(svc('s1'));
    final r = await repo.addService(svc('s1', name: 'Lain'));
    expect(r.isLeft(), true);
    expect(serviceBox.length, 1);
    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.single.name, 'Bubut poros');
  });

  test('JSON rusak dilewati, jasa lain tetap terbaca, data asli tidak dihapus',
      () async {
    await repo.addService(svc('s1'));
    await serviceBox.put('rusak', '{ini bukan json');
    await serviceBox.put('rusak2', '{"id":"x","name":"","categoryId":"c"}');

    final list = (await repo.getServices()).getOrElse((_) => throw 'gagal');
    expect(list.items.map((e) => e.id), ['s1']);
    expect(list.skipped, 2);

    // Data rusak masih ada di penyimpanan (tidak dihapus/ditimpa).
    expect(serviceBox.get('rusak'), '{ini bukan json');
    expect(serviceBox.containsKey('rusak2'), true);

    // Operasi lain tetap berjalan.
    expect((await repo.addService(svc('s2', name: 'Las'))).isRight(), true);
    expect(serviceBox.get('rusak'), '{ini bukan json');
  });

  test('mengubah status jasa yang rusak ditolak tanpa menimpa data', () async {
    await serviceBox.put('rusak', '{ini bukan json');
    final r = await repo.setServiceActive('rusak', false);
    expect(r.isLeft(), true);
    expect(serviceBox.get('rusak'), '{ini bukan json');
  });

  group('kategori awal (seed)', () {
    test('terisi sekali, tanpa duplikat setelah dibaca berulang', () async {
      for (var i = 0; i < 3; i++) {
        await repo.getCategories();
        await repo.getServices();
      }
      final cats =
          (await repo.getCategories()).getOrElse((_) => throw 'gagal');
      expect(cats.items.length, ServiceCategory.defaults.length);
      expect(cats.items.map((c) => c.id).toSet().length, cats.items.length);
      expect(cats.items.last.id, ServiceCategory.lainnyaId);
    });

    test('tidak duplikat walau repository baru dibuat berkali-kali', () async {
      await newRepo().getCategories();
      await newRepo().getCategories();
      final cats =
          (await newRepo().getCategories()).getOrElse((_) => throw 'gagal');
      expect(cats.items.length, ServiceCategory.defaults.length);
      expect(categoryBox.length, ServiceCategory.defaults.length);
    });

    test('kategori yang sudah diubah namanya tidak ditimpa seed', () async {
      await repo.getCategories();
      await repo.updateCategory(
          const ServiceCategory(id: 'kategori-las', name: 'Las Listrik'));
      settingsBox.delete(ServiceRepositoryImpl.seedFlagKey);
      final cats =
          (await newRepo().getCategories()).getOrElse((_) => throw 'gagal');
      expect(cats.items.where((c) => c.id == 'kategori-las').single.name,
          'Las Listrik');
      expect(cats.items.length, ServiceCategory.defaults.length);
    });

    test('kategori awal yang sengaja dihapus tidak muncul lagi', () async {
      await repo.getCategories();
      expect((await repo.deleteCategory('kategori-press')).isRight(), true);
      final cats =
          (await newRepo().getCategories()).getOrElse((_) => throw 'gagal');
      expect(cats.items.any((c) => c.id == 'kategori-press'), false);
    });
  });

  group('kategori', () {
    test('tambah, ubah nama, nama duplikat ditolak', () async {
      expect(
        (await repo.addCategory(
                const ServiceCategory(id: 'k-baru', name: 'Gerinda')))
            .isRight(),
        true,
      );
      expect(
        (await repo.addCategory(
                const ServiceCategory(id: 'k-baru2', name: 'gerinda')))
            .isLeft(),
        true,
      );
      expect(
        (await repo.updateCategory(
                const ServiceCategory(id: 'k-baru', name: 'Gerinda Silinder')))
            .isRight(),
        true,
      );
    });

    test('kategori yang masih dipakai jasa tidak bisa dihapus', () async {
      await repo.addService(svc('s1'));
      final r = await repo.deleteCategory(bubut);
      expect(r.isLeft(), true);
      expect(categoryBox.containsKey(bubut), true);
    });

    test('kategori Lainnya tidak bisa dihapus', () async {
      await repo.getCategories();
      final r = await repo.deleteCategory(ServiceCategory.lainnyaId);
      expect(r.isLeft(), true);
      expect(categoryBox.containsKey(ServiceCategory.lainnyaId), true);
    });

    test('kategori rusak dilewati dan tidak dihapus', () async {
      await repo.getCategories();
      await categoryBox.put('k-rusak', 'bukan json');
      final cats =
          (await repo.getCategories()).getOrElse((_) => throw 'gagal');
      expect(cats.skipped, 1);
      expect(categoryBox.get('k-rusak'), 'bukan json');
    });
  });

  test('JSON jasa tersimpan memakai bilangan bulat untuk harga', () async {
    await repo.addService(svc('s1'));
    final raw = serviceBox.get('s1')!;
    expect(raw.contains('"defaultPrice":150000'), true);
    expect(ServiceModel.decode(raw).defaultPrice, 150000);
  });
}
