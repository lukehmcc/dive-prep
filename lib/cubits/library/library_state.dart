import '../../models/jellyfin_models.dart';

abstract class LibraryState {}
class LibraryInitial extends LibraryState {}
class LibraryLoading extends LibraryState {}
class LibraryError extends LibraryState { final String msg; LibraryError(this.msg); }
class LibraryLoaded extends LibraryState {
  final List<JellyfinItem> items;
  LibraryLoaded(this.items);
}
