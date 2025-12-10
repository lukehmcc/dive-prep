import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../models/jellyfin_models.dart';
import 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  final Dio client;
  final String userId;

  LibraryCubit({required this.client, required this.userId}) : super(LibraryInitial());

  // Generic fetcher
  Future<void> fetchItems({
    String? parentId, 
    required String includeTypes, 
    String sortBy = 'SortName'
  }) async {
    emit(LibraryLoading());
    try {
      final response = await client.get(
        '/Users/$userId/Items',
        queryParameters: {
          'ParentId': parentId,
          'Recursive': parentId == null, // Recursive only if root
          'IncludeItemTypes': includeTypes,
          'SortBy': sortBy,
          'SortOrder': 'Descending',
          'Limit': 100,
          // We added MediaSources here so we know the file extension (mkv/mp4) for batch downloads
          'Fields': 'PrimaryImageAspectRatio,MediaSources',
        },
      );
      
      final List data = response.data['Items'];
      final items = data.map((json) => JellyfinItem.fromJson(json)).toList();
      emit(LibraryLoaded(items));
    } catch (e) {
      emit(LibraryError(e.toString()));
    }
  }
}
