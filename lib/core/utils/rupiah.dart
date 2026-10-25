/// Memformat bilangan bulat Rupiah, mis. 150000 -> "Rp150.000".
///
/// Sengaja tidak memakai data locale intl supaya hasilnya selalu sama
/// (tanpa spasi tak terlihat) dan aman untuk dicetak di printer thermal.
String formatRupiah(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${negative ? '-' : ''}Rp$grouped';
}
