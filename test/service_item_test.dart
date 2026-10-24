import 'package:billing_app/core/error/failure.dart';
import 'package:billing_app/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/repositories/product_repository.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Repository palsu: hanya berisi sparepart, mencatat apakah ada yang
/// menulis (add/update/delete) ke "database" selama transaksi.
class _FakeProductRepository implements ProductRepository {
  final List<Product> products;
  int writeCalls = 0;

  _FakeProductRepository(this.products);

  @override
  Future<Either<Failure, List<Product>>> getProducts() async =>
      Right(products);

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    final match = products.where((p) => p.barcode == barcode);
    if (match.isEmpty) return Left(CacheFailure('Product not found'));
    return Right(match.first);
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    writeCalls++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    writeCalls++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    writeCalls++;
    return const Right(null);
  }
}

void main() {
  const piston = Product(
    id: 'p1',
    name: 'Piston 54 mm',
    barcode: '8999001',
    price: 125000,
    stock: 10,
  );
  const ring = Product(
    id: 'p2',
    name: 'Ring piston',
    barcode: '8999002',
    price: 35000,
    stock: 4,
  );
  const korter = Product(
    id: 'svc-1',
    name: 'Korter blok',
    barcode: '',
    price: 150000,
    isService: true,
  );

  late _FakeProductRepository repo;
  late BillingBloc bloc;

  setUp(() {
    repo = _FakeProductRepository([piston, ring]);
    bloc = BillingBloc(getProductByBarcodeUseCase: GetProductByBarcodeUseCase(repo));
  });

  tearDown(() => bloc.close());

  // Event dijalankan async; satu giliran timer cukup untuk handler sinkron.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('Product.isService', () {
    test('produk/sparepart lama default-nya BUKAN jasa', () {
      expect(piston.isService, isFalse);
      expect(piston.stock, 10);
      expect(piston.barcode, '8999001');
    });

    test('jasa ditandai isService, tanpa barcode dan tanpa stok', () {
      expect(korter.isService, isTrue);
      expect(korter.barcode, isEmpty);
      expect(korter.stock, 0);
    });
  });

  group('Transaksi jasa + sparepart', () {
    test('jasa dan sparepart bisa dalam SATU transaksi, total benar', () async {
      bloc.add(const AddProductToCartEvent(korter));
      bloc.add(const AddProductToCartEvent(piston));
      bloc.add(const AddProductToCartEvent(ring));
      await settle();

      expect(bloc.state.cartItems.length, 3);
      expect(bloc.state.cartItems.where((i) => i.product.isService).length, 1);
      expect(bloc.state.totalAmount, 150000 + 125000 + 35000); // 310.000
    });

    test('jumlah jasa bisa diubah dan ikut ke total', () async {
      bloc.add(const AddProductToCartEvent(korter));
      bloc.add(const UpdateQuantityEvent('svc-1', 2));
      await settle();

      expect(bloc.state.totalAmount, 300000);
    });

    test('scan barcode sparepart tetap menambah ke cart seperti biasa', () async {
      bloc.add(const ScanBarcodeEvent('8999001'));
      await settle();
      await settle();

      expect(bloc.state.cartItems.single.product, piston);
    });

    test('barcode kosong tidak menemukan jasa (jasa tidak punya barcode)', () async {
      bloc.add(const AddProductToCartEvent(korter));
      bloc.add(const ScanBarcodeEvent(''));
      await settle();
      await settle();

      expect(bloc.state.error, isNotNull);
      expect(bloc.state.cartItems.length, 1); // hanya jasa yang tadi ditambah
    });

    test('transaksi tidak menulis/mengubah data produk (stok tetap)', () async {
      bloc.add(const AddProductToCartEvent(korter));
      bloc.add(const AddProductToCartEvent(piston));
      await settle();

      expect(repo.writeCalls, 0);
      expect(repo.products.first.stock, 10);
    });
  });
}
