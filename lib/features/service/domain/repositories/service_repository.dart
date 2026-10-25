import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/load_result.dart';
import '../entities/service_category.dart';
import '../entities/service_item.dart';

abstract class ServiceRepository {
  // Jasa
  Future<Either<Failure, LoadResult<ServiceItem>>> getServices();
  Future<Either<Failure, void>> addService(ServiceItem service);
  Future<Either<Failure, void>> updateService(ServiceItem service);
  Future<Either<Failure, void>> setServiceActive(String id, bool isActive);
  Future<Either<Failure, void>> deleteService(String id);

  // Kategori
  Future<Either<Failure, LoadResult<ServiceCategory>>> getCategories();
  Future<Either<Failure, void>> addCategory(ServiceCategory category);
  Future<Either<Failure, void>> updateCategory(ServiceCategory category);
  Future<Either<Failure, void>> deleteCategory(String id);
}
