class AppValidators {
  static String? Function(String?) required(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Harga wajib diisi';
    }
    if (double.tryParse(value) == null) {
      return 'Masukkan angka yang valid';
    }
    if (double.parse(value) < 0) {
      return 'Harga tidak boleh negatif';
    }
    return null;
  }
}
