part of 'details_cubit.dart';

abstract class DetailsState {}

class DetailsInitial extends DetailsState {}

class DetailsLoaded extends DetailsState {
  String? bgTag;
  DetailsLoaded(this.bgTag);
}
