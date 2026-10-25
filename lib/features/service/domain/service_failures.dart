import '../../../core/error/failure.dart';

/// Kegagalan karena input/aturan tidak terpenuhi (bukan kesalahan penyimpanan).
/// [message] sudah berbahasa Indonesia dan aman ditampilkan ke pengguna.
class ServiceValidationFailure extends Failure {
  const ServiceValidationFailure(String message) : super(message);
}
