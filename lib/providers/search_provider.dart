import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/place.dart';
import '../core/api_client.dart';
import 'api_providers.dart';

// A simple provider that fetches search results based on a query string
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<ApiResponse<List<Place>>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) {
    return ApiResponse(success: true, data: []);
  }
  
  final searchService = ref.read(searchServiceProvider);
  return searchService.searchPlaces(query);
});
