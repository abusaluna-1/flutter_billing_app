import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/load_result.dart';
import '../entities/service_category.dart';
import '../entities/service_item.dart';
import '../repositories/service_repository.dart';

// ---------------------------------------------------------------- Jasa

class GetServicesUseCase implements UseCase<LoadResult<ServiceItem>, NoParams> {
  final ServiceRepository repository;

  GetServicesUseCase(this.repository);

  @override
  Future<Either<Failure, LoadResult<ServiceItem>>> call(NoParams params) {
    return repository.getServices();
  }
}

class AddServiceUseCase implements UseCase<void, ServiceItem> {
  final ServiceRepository repository;

  AddServiceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ServiceItem params) {
    return repository.addService(params);
  }
}

class UpdateServiceUseCase implements UseCase<void, ServiceItem> {
  final ServiceRepository repository;

  UpdateServiceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ServiceItem params) {
    return repository.updateService(params);
  }
}

class SetServiceActiveParams extends Equatable {
  final String id;
  final bool isActive;

  const SetServiceActiveParams({required this.id, required this.isActive});

  @override
  List<Object?> get props => [id, isActive];
}

class SetServiceActiveUseCase
    implements UseCase<void, SetServiceActiveParams> {
  final ServiceRepository repository;

  SetServiceActiveUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SetServiceActiveParams params) {
    return repository.setServiceActive(params.id, params.isActive);
  }
}

class DeleteServiceUseCase implements UseCase<void, String> {
  final ServiceRepository repository;

  DeleteServiceUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteService(params);
  }
}

// ------------------------------------------------------------ Kategori

class GetServiceCategoriesUseCase
    implements UseCase<LoadResult<ServiceCategory>, NoParams> {
  final ServiceRepository repository;

  GetServiceCategoriesUseCase(this.repository);

  @override
  Future<Either<Failure, LoadResult<ServiceCategory>>> call(NoParams params) {
    return repository.getCategories();
  }
}

class AddServiceCategoryUseCase implements UseCase<void, ServiceCategory> {
  final ServiceRepository repository;

  AddServiceCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ServiceCategory params) {
    return repository.addCategory(params);
  }
}

class UpdateServiceCategoryUseCase implements UseCase<void, ServiceCategory> {
  final ServiceRepository repository;

  UpdateServiceCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ServiceCategory params) {
    return repository.updateCategory(params);
  }
}

class DeleteServiceCategoryUseCase implements UseCase<void, String> {
  final ServiceRepository repository;

  DeleteServiceCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteCategory(params);
  }
}
