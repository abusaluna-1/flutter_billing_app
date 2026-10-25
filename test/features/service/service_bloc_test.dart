import 'dart:async';

import 'package:billing_app/features/service/domain/entities/load_result.dart';
import 'package:billing_app/features/service/domain/entities/service_category.dart';
import 'package:billing_app/features/service/domain/entities/service_item.dart';
import 'package:billing_app/features/service/domain/repositories/service_repository.dart';
import 'package:billing_app/features/service/domain/service_failures.dart';
import 'package:billing_app/features/service/domain/usecases/service_usecases.dart';
import 'package:billing_app/features/service/presentation/bloc/service_bloc.dart';
import 'package:billing_app/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class FakeServiceRepository implements ServiceRepository {
  final Map<String, ServiceItem> services = {};
  final List<ServiceCategory> categories = [
    const ServiceCategory(id: 'kategori-bubut', name: 'Bubut'),
  ];
  bool failWrites = false;

  Either<Failure, void> _write(void Function() f) {
    if (failWrites) return const Left(CacheFailure('Gagal menyimpan jasa. Coba lagi.'));
    f();
    return const Right(null);
  }

  @override
  Future<Either<Failure, LoadResult<ServiceItem>>> getServices() async =>
      Right(LoadResult(items: services.values.toList()));

  @override
  Future<Either<Failure, void>> addService(ServiceItem s) async =>
      _write(() => services[s.id] = s);

  @override
  Future<Either<Failure, void>> updateService(ServiceItem s) async =>
      _write(() => services[s.id] = s);

  @override
  Future<Either<Failure, void>> setServiceActive(String id, bool a) async =>
      _write(() => services[id] = services[id]!.copyWith(isActive: a));

  @override
  Future<Either<Failure, void>> deleteService(String id) async =>
      _write(() => services.remove(id));

  @override
  Future<Either<Failure, LoadResult<ServiceCategory>>> getCategories() async =>
      Right(LoadResult(items: List.of(categories), skipped: 1));

  @override
  Future<Either<Failure, void>> addCategory(ServiceCategory c) async =>
      _write(() => categories.add(c));

  @override
  Future<Either<Failure, void>> updateCategory(ServiceCategory c) async =>
      _write(() {});

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async =>
      Left(const ServiceValidationFailure('Kategori masih dipakai 1 jasa.'));
}

ServiceBloc buildBloc(FakeServiceRepository r) => ServiceBloc(
      getServices: GetServicesUseCase(r),
      addService: AddServiceUseCase(r),
      updateService: UpdateServiceUseCase(r),
      setServiceActive: SetServiceActiveUseCase(r),
      deleteService: DeleteServiceUseCase(r),
      getCategories: GetServiceCategoriesUseCase(r),
      addCategory: AddServiceCategoryUseCase(r),
      updateCategory: UpdateServiceCategoryUseCase(r),
      deleteCategory: DeleteServiceCategoryUseCase(r),
    );

const item =
    ServiceItem(id: 's1', name: 'Bubut poros', categoryId: 'kategori-bubut');

Future<ServiceState> nextState(
    ServiceBloc bloc, bool Function(ServiceState) test) {
  return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 5));
}

void main() {
  test('memuat jasa dan kategori, menghitung data rusak', () async {
    final repo = FakeServiceRepository();
    final bloc = buildBloc(repo);
    final f = nextState(bloc, (s) => s.status == ServiceStatus.loaded);
    bloc.add(const LoadServices());
    final s = await f;
    expect(s.categories.length, 1);
    expect(s.corruptCategoryCount, 1);
    await bloc.close();
  });

  test('tambah jasa berhasil lalu daftar dimuat ulang', () async {
    final repo = FakeServiceRepository();
    final bloc = buildBloc(repo);
    final f = nextState(bloc, (s) => s.message == 'Jasa berhasil disimpan');
    bloc.add(const AddServiceEvent(item));
    final s = await f;
    expect(s.isError, false);
    expect(s.services.single.id, 's1');
    await bloc.close();
  });

  test('nonaktifkan jasa', () async {
    final repo = FakeServiceRepository()..services['s1'] = item;
    final bloc = buildBloc(repo);
    final f = nextState(bloc, (s) => s.message == 'Jasa dinonaktifkan');
    bloc.add(const ToggleServiceActiveEvent(id: 's1', isActive: false));
    final s = await f;
    expect(s.services.single.isActive, false);
    await bloc.close();
  });

  test('hapus jasa', () async {
    final repo = FakeServiceRepository()..services['s1'] = item;
    final bloc = buildBloc(repo);
    final f = nextState(bloc, (s) => s.message == 'Jasa dihapus');
    bloc.add(const DeleteServiceEvent('s1'));
    final s = await f;
    expect(s.services, isEmpty);
    await bloc.close();
  });

  test('gagal menyimpan: pesan error dikirim dan data lama dipertahankan',
      () async {
    final repo = FakeServiceRepository()..services['s1'] = item;
    final bloc = buildBloc(repo);
    final loaded = nextState(bloc, (s) => s.status == ServiceStatus.loaded);
    bloc.add(const LoadServices());
    await loaded;

    repo.failWrites = true;
    final f = nextState(bloc, (s) => s.isError);
    bloc.add(const UpdateServiceEvent(
        ServiceItem(id: 's1', name: 'Baru', categoryId: 'kategori-bubut')));
    final s = await f;
    expect(s.message, 'Gagal menyimpan jasa. Coba lagi.');
    expect(s.services.single.name, 'Bubut poros');
    await bloc.close();
  });

  test('hapus kategori yang dipakai menampilkan pesan error', () async {
    final bloc = buildBloc(FakeServiceRepository());
    final f = nextState(bloc, (s) => s.isError);
    bloc.add(const DeleteCategoryEvent('kategori-bubut'));
    final s = await f;
    expect(s.message, contains('masih dipakai'));
    await bloc.close();
  });
}
