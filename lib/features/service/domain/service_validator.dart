import 'entities/service_item.dart';

/// Aturan validasi master jasa. Dipakai oleh formulir DAN repository
/// (pertahanan berlapis, supaya data tidak valid tidak pernah tersimpan).
/// Semua pesan berbahasa Indonesia.
class ServiceValidator {
  static const int maxNameLength = 80;
  static const int maxUnitLength = 20;
  static const int maxNoteLength = 200;
  static const int maxCategoryNameLength = 30;

  /// Batas harga: Rp1.000.000.000 (satu miliar).
  static const int maxPrice = 1000000000;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nama jasa wajib diisi';
    if (v.length > maxNameLength) {
      return 'Nama jasa maksimal $maxNameLength karakter';
    }
    return null;
  }

  /// Validasi teks harga dari formulir. Kosong dianggap valid
  /// (harga standar boleh belum ditentukan).
  static String? priceText(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.startsWith('-')) return 'Harga tidak boleh negatif';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Harga hanya boleh berisi angka';
    final parsed = int.tryParse(v);
    if (parsed == null || parsed > maxPrice) return 'Harga terlalu besar';
    return null;
  }

  /// Mengubah teks harga menjadi angka Rupiah. Kosong/tidak valid -> null.
  static int? parsePrice(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  /// Validasi nilai harga. `null` valid (harga belum ditentukan).
  static String? price(int? value) {
    if (value == null) return null;
    if (value < 0) return 'Harga tidak boleh negatif';
    if (value > maxPrice) return 'Harga terlalu besar';
    return null;
  }

  static String? unit(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Satuan wajib diisi';
    if (v.length > maxUnitLength) {
      return 'Satuan maksimal $maxUnitLength karakter';
    }
    return null;
  }

  static String? note(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > maxNoteLength) {
      return 'Catatan maksimal $maxNoteLength karakter';
    }
    return null;
  }

  static String? categoryId(String? value) {
    if (value == null || value.trim().isEmpty) return 'Pilih kategori jasa';
    return null;
  }

  static String? categoryName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nama kategori wajib diisi';
    if (v.length > maxCategoryNameLength) {
      return 'Nama kategori maksimal $maxCategoryNameLength karakter';
    }
    return null;
  }

  /// Validasi menyeluruh satu jasa. Mengembalikan pesan kesalahan pertama,
  /// atau null jika semuanya valid. (Keberadaan kategori dicek di repository.)
  static String? service(ServiceItem s) {
    if (s.id.trim().isEmpty) return 'ID jasa tidak valid';
    return name(s.name) ??
        categoryId(s.categoryId) ??
        price(s.defaultPrice) ??
        unit(s.unit) ??
        note(s.note);
  }
}
