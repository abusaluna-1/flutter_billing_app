import 'dart:io';

import 'package:billing_app/features/shop/data/models/shop_model.dart';
import 'package:billing_app/features/shop/data/repositories/shop_repository_impl.dart';
import 'package:billing_app/features/shop/domain/entities/shop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('garagepos_shop_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ShopModelAdapter());
    }
    await Hive.openBox<ShopModel>('shop');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('instalasi baru: semua kolom identitas kosong', () async {
    final result = await ShopRepositoryImpl().getShop();
    final shop = result.getOrElse((_) => throw 'gagal');
    expect(shop.name, '');
    expect(shop.addressLine1, '');
    expect(shop.addressLine2, '');
    expect(shop.phoneNumber, '');
    expect(shop.upiId, '');
    expect(shop.footerText, '');
  });

  test('identitas yang sudah tersimpan tetap terbaca', () async {
    final repo = ShopRepositoryImpl();
    await repo.updateShop(const Shop(
      name: 'Bengkel Maju',
      addressLine1: 'Jl. Mawar 1',
      phoneNumber: '0812',
      footerText: 'Terima kasih',
    ));
    final shop = (await repo.getShop()).getOrElse((_) => throw 'gagal');
    expect(shop.name, 'Bengkel Maju');
    expect(shop.addressLine1, 'Jl. Mawar 1');
    expect(shop.phoneNumber, '0812');
    expect(shop.footerText, 'Terima kasih');
  });
}
