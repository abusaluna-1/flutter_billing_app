import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';

  // Master jasa & kategori: box terpisah dari produk, isinya teks JSON
  // (tanpa adapter Hive, tanpa code generation).
  static const String serviceBoxName = 'service_items';
  static const String serviceCategoryBoxName = 'service_categories';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value

    // Box jasa dibuka terpisah: jika gagal dibuka, aplikasi (kasir, produk,
    // printer) tetap bisa dipakai; fitur jasa akan menampilkan pesan gagal.
    try {
      await Hive.openBox<String>(serviceBoxName);
      await Hive.openBox<String>(serviceCategoryBoxName);
    } catch (_) {
      // Sengaja diabaikan; lihat ServiceRepositoryImpl yang menangani box
      // yang tidak tersedia dengan pesan kesalahan.
    }
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<String> get serviceBox => Hive.box<String>(serviceBoxName);
  static Box<String> get serviceCategoryBox =>
      Hive.box<String>(serviceCategoryBoxName);
}
