import 'package:billing_app/features/service/domain/entities/service_item.dart';
import 'package:billing_app/features/service/domain/service_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nama wajib diisi', () {
    expect(ServiceValidator.name(''), isNotNull);
    expect(ServiceValidator.name('   '), isNotNull);
    expect(ServiceValidator.name(null), isNotNull);
    expect(ServiceValidator.name('Bubut'), isNull);
    expect(ServiceValidator.name('a' * 81), isNotNull);
  });

  test('harga boleh kosong, tidak boleh negatif / bukan angka / terlalu besar',
      () {
    expect(ServiceValidator.priceText(''), isNull);
    expect(ServiceValidator.priceText(null), isNull);
    expect(ServiceValidator.priceText('150000'), isNull);
    expect(ServiceValidator.priceText('-5'), 'Harga tidak boleh negatif');
    expect(ServiceValidator.priceText('abc'), isNotNull);
    expect(ServiceValidator.priceText('99999999999'), isNotNull);
    expect(ServiceValidator.parsePrice(''), isNull);
    expect(ServiceValidator.parsePrice('150000'), 150000);
    expect(ServiceValidator.price(-1), isNotNull);
    expect(ServiceValidator.price(0), isNull);
    expect(ServiceValidator.price(null), isNull);
  });

  test('kategori wajib dipilih', () {
    expect(ServiceValidator.categoryId(null), isNotNull);
    expect(ServiceValidator.categoryId(''), isNotNull);
    expect(ServiceValidator.categoryId('kategori-las'), isNull);
  });

  test('validasi gabungan', () {
    expect(
      ServiceValidator.service(const ServiceItem(
          id: 'a', name: 'Las', categoryId: 'kategori-las')),
      isNull,
    );
    expect(
      ServiceValidator.service(const ServiceItem(
          id: 'a', name: '', categoryId: 'kategori-las')),
      isNotNull,
    );
    expect(
      ServiceValidator.service(const ServiceItem(
          id: 'a', name: 'Las', categoryId: 'kategori-las', defaultPrice: -1)),
      isNotNull,
    );
  });
}
