import 'dart:convert';

import 'package:billing_app/features/service/data/models/service_model.dart';
import 'package:billing_app/features/service/domain/entities/service_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = ServiceItem(
    id: 's1',
    name: 'Bubut poros',
    categoryId: 'kategori-bubut',
    defaultPrice: 150000,
    unit: 'Unit',
    note: 'catatan',
    isActive: false,
  );

  test('encode lalu decode menghasilkan data yang sama', () {
    final decoded = ServiceModel.decode(ServiceModel.encode(item));
    expect(decoded.id, item.id);
    expect(decoded.name, item.name);
    expect(decoded.categoryId, item.categoryId);
    expect(decoded.defaultPrice, 150000);
    expect(decoded.unit, 'Unit');
    expect(decoded.note, 'catatan');
    expect(decoded.isActive, false);
  });

  test('harga kosong (null) tetap null setelah roundtrip', () {
    final decoded = ServiceModel.decode(ServiceModel.encode(
      const ServiceItem(id: 's2', name: 'Las', categoryId: 'kategori-las'),
    ));
    expect(decoded.defaultPrice, isNull);
    expect(decoded.unit, ServiceItem.defaultUnit);
    expect(decoded.isActive, true);
  });

  test('field opsional yang hilang diberi nilai bawaan', () {
    final decoded = ServiceModel.decode(jsonEncode(
        {'id': 's3', 'name': 'Frais', 'categoryId': 'kategori-frais'}));
    expect(decoded.defaultPrice, isNull);
    expect(decoded.unit, ServiceItem.defaultUnit);
    expect(decoded.note, '');
    expect(decoded.isActive, true);
  });

  test('JSON rusak melempar FormatException', () {
    expect(() => ServiceModel.decode('{bukan json'),
        throwsA(isA<FormatException>()));
    expect(() => ServiceModel.decode('[1,2]'), throwsA(isA<FormatException>()));
    expect(() => ServiceModel.decode('null'), throwsA(isA<FormatException>()));
  });

  test('harga negatif, pecahan, atau teks ditolak', () {
    for (final price in [-1, 1.5, 'seratus']) {
      expect(
        () => ServiceModel.decode(jsonEncode({
          'id': 's4',
          'name': 'X',
          'categoryId': 'c',
          'defaultPrice': price,
        })),
        throwsA(isA<FormatException>()),
        reason: 'harga $price harus ditolak',
      );
    }
  });

  test('nama atau kategori kosong ditolak', () {
    expect(
      () => ServiceModel.decode(
          jsonEncode({'id': 's5', 'name': ' ', 'categoryId': 'c'})),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ServiceModel.decode(jsonEncode({'id': 's5', 'name': 'A'})),
      throwsA(isA<FormatException>()),
    );
  });
}
