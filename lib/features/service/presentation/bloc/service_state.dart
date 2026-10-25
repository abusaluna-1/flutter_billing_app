part of 'service_bloc.dart';

enum ServiceStatus { initial, loading, loaded, error }

class ServiceState extends Equatable {
  final ServiceStatus status;
  final List<ServiceItem> services;
  final List<ServiceCategory> categories;

  /// Jumlah data yang tidak terbaca (rusak). Data aslinya tidak dihapus.
  final int corruptServiceCount;
  final int corruptCategoryCount;

  /// Pesan terakhir untuk pengguna (sukses atau gagal).
  final String? message;
  final bool isError;

  /// Naik setiap kali ada pesan baru, supaya pesan yang sama dua kali
  /// berturut-turut tetap memicu listener.
  final int feedbackSeq;

  const ServiceState({
    this.status = ServiceStatus.initial,
    this.services = const [],
    this.categories = const [],
    this.corruptServiceCount = 0,
    this.corruptCategoryCount = 0,
    this.message,
    this.isError = false,
    this.feedbackSeq = 0,
  });

  ServiceState copyWith({
    ServiceStatus? status,
    List<ServiceItem>? services,
    List<ServiceCategory>? categories,
    int? corruptServiceCount,
    int? corruptCategoryCount,
    String? message,
    bool clearMessage = false,
    bool? isError,
    int? feedbackSeq,
  }) {
    return ServiceState(
      status: status ?? this.status,
      services: services ?? this.services,
      categories: categories ?? this.categories,
      corruptServiceCount: corruptServiceCount ?? this.corruptServiceCount,
      corruptCategoryCount: corruptCategoryCount ?? this.corruptCategoryCount,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
      feedbackSeq: feedbackSeq ?? this.feedbackSeq,
    );
  }

  @override
  List<Object?> get props => [
        status,
        services,
        categories,
        corruptServiceCount,
        corruptCategoryCount,
        message,
        isError,
        feedbackSeq,
      ];
}
