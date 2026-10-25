import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/load_result.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_item.dart';
import '../../domain/usecases/service_usecases.dart';

part 'service_event.dart';
part 'service_state.dart';

class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  final GetServicesUseCase getServices;
  final AddServiceUseCase addService;
  final UpdateServiceUseCase updateService;
  final SetServiceActiveUseCase setServiceActive;
  final DeleteServiceUseCase deleteService;
  final GetServiceCategoriesUseCase getCategories;
  final AddServiceCategoryUseCase addCategory;
  final UpdateServiceCategoryUseCase updateCategory;
  final DeleteServiceCategoryUseCase deleteCategory;

  ServiceBloc({
    required this.getServices,
    required this.addService,
    required this.updateService,
    required this.setServiceActive,
    required this.deleteService,
    required this.getCategories,
    required this.addCategory,
    required this.updateCategory,
    required this.deleteCategory,
  }) : super(const ServiceState()) {
    on<LoadServices>(_onLoad);
    on<AddServiceEvent>(_onAddService);
    on<UpdateServiceEvent>(_onUpdateService);
    on<ToggleServiceActiveEvent>(_onToggleActive);
    on<DeleteServiceEvent>(_onDeleteService);
    on<AddCategoryEvent>(_onAddCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
  }

  Future<void> _onLoad(LoadServices event, Emitter<ServiceState> emit) async {
    emit(state.copyWith(status: ServiceStatus.loading));
    await _reload(emit);
  }

  Future<void> _onAddService(
      AddServiceEvent event, Emitter<ServiceState> emit) {
    return _mutate(
        emit, () => addService(event.service), 'Jasa berhasil disimpan');
  }

  Future<void> _onUpdateService(
      UpdateServiceEvent event, Emitter<ServiceState> emit) {
    return _mutate(
        emit, () => updateService(event.service), 'Perubahan jasa disimpan');
  }

  Future<void> _onToggleActive(
      ToggleServiceActiveEvent event, Emitter<ServiceState> emit) {
    return _mutate(
      emit,
      () => setServiceActive(
        SetServiceActiveParams(id: event.id, isActive: event.isActive),
      ),
      event.isActive ? 'Jasa diaktifkan' : 'Jasa dinonaktifkan',
    );
  }

  Future<void> _onDeleteService(
      DeleteServiceEvent event, Emitter<ServiceState> emit) {
    return _mutate(emit, () => deleteService(event.id), 'Jasa dihapus');
  }

  Future<void> _onAddCategory(
      AddCategoryEvent event, Emitter<ServiceState> emit) {
    return _mutate(
        emit, () => addCategory(event.category), 'Kategori ditambahkan');
  }

  Future<void> _onUpdateCategory(
      UpdateCategoryEvent event, Emitter<ServiceState> emit) {
    return _mutate(
        emit, () => updateCategory(event.category), 'Kategori diperbarui');
  }

  Future<void> _onDeleteCategory(
      DeleteCategoryEvent event, Emitter<ServiceState> emit) {
    return _mutate(emit, () => deleteCategory(event.id), 'Kategori dihapus');
  }

  /// Menjalankan satu perubahan data. Jika gagal: data di layar dipertahankan
  /// dan pesan kesalahan dikirim. Jika berhasil: data dimuat ulang.
  Future<void> _mutate(
    Emitter<ServiceState> emit,
    Future<Either<Failure, void>> Function() action,
    String successMessage,
  ) async {
    final result = await action();
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(
        message: failure.message,
        isError: true,
        feedbackSeq: state.feedbackSeq + 1,
      ));
      return;
    }
    await _reload(emit, successMessage: successMessage);
  }

  Future<void> _reload(Emitter<ServiceState> emit,
      {String? successMessage}) async {
    final categoriesResult = await getCategories(NoParams());
    final servicesResult = await getServices(NoParams());

    final failure = categoriesResult.fold<Failure?>((f) => f, (_) => null) ??
        servicesResult.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(
        status: ServiceStatus.error,
        message: failure.message,
        isError: true,
        feedbackSeq: state.feedbackSeq + 1,
      ));
      return;
    }

    final categories = categoriesResult.fold<LoadResult<ServiceCategory>>(
      (_) => const LoadResult<ServiceCategory>(),
      (r) => r,
    );
    final services = servicesResult.fold<LoadResult<ServiceItem>>(
      (_) => const LoadResult<ServiceItem>(),
      (r) => r,
    );

    emit(state.copyWith(
      status: ServiceStatus.loaded,
      services: services.items,
      categories: categories.items,
      corruptServiceCount: services.skipped,
      corruptCategoryCount: categories.skipped,
      message: successMessage,
      clearMessage: successMessage == null,
      isError: false,
      feedbackSeq:
          successMessage == null ? state.feedbackSeq : state.feedbackSeq + 1,
    ));
  }
}
