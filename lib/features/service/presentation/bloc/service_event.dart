part of 'service_bloc.dart';

abstract class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object?> get props => [];
}

/// Memuat jasa & kategori dari penyimpanan.
class LoadServices extends ServiceEvent {
  const LoadServices();
}

class AddServiceEvent extends ServiceEvent {
  final ServiceItem service;
  const AddServiceEvent(this.service);

  @override
  List<Object?> get props => [service];
}

class UpdateServiceEvent extends ServiceEvent {
  final ServiceItem service;
  const UpdateServiceEvent(this.service);

  @override
  List<Object?> get props => [service];
}

class ToggleServiceActiveEvent extends ServiceEvent {
  final String id;
  final bool isActive;
  const ToggleServiceActiveEvent({required this.id, required this.isActive});

  @override
  List<Object?> get props => [id, isActive];
}

class DeleteServiceEvent extends ServiceEvent {
  final String id;
  const DeleteServiceEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class AddCategoryEvent extends ServiceEvent {
  final ServiceCategory category;
  const AddCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class UpdateCategoryEvent extends ServiceEvent {
  final ServiceCategory category;
  const UpdateCategoryEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class DeleteCategoryEvent extends ServiceEvent {
  final String id;
  const DeleteCategoryEvent(this.id);

  @override
  List<Object?> get props => [id];
}
