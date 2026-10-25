import 'package:equatable/equatable.dart';

/// Hasil membaca daftar dari penyimpanan.
///
/// [skipped] = jumlah data yang tidak terbaca (rusak) dan dilewati.
/// Data rusak tidak dihapus dan tidak ditimpa; hanya tidak ditampilkan.
class LoadResult<T> extends Equatable {
  final List<T> items;
  final int skipped;

  const LoadResult({this.items = const [], this.skipped = 0});

  @override
  List<Object?> get props => [items, skipped];
}
