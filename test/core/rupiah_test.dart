import 'package:billing_app/core/utils/rupiah.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatRupiah memakai titik sebagai pemisah ribuan', () {
    expect(formatRupiah(0), 'Rp0');
    expect(formatRupiah(999), 'Rp999');
    expect(formatRupiah(1000), 'Rp1.000');
    expect(formatRupiah(150000), 'Rp150.000');
    expect(formatRupiah(1250000), 'Rp1.250.000');
    expect(formatRupiah(-2500), '-Rp2.500');
  });
}
