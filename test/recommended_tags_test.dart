import 'package:daviewer/features/search/search_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weights favourites over watched over browsed', () {
    final result = recommendedTagsFrom(<List<String>, int>{
      <String>['digitalart']: 3,
      <String>['digitalart', 'anime']: 2,
      <String>['anime', 'landscape']: 1,
    });
    // digitalart: 3+2=5, anime: 2+1=3, landscape: 1
    expect(result, <String>['digitalart', 'anime', 'landscape']);
  });

  test('normalizes case and whitespace', () {
    final result = recommendedTagsFrom(<List<String>, int>{
      <String>['  DigitalArt ', 'Anime']: 1,
    });
    expect(result, <String>['digitalart', 'anime']);
  });

  test('returns empty for no tags', () {
    expect(recommendedTagsFrom(<List<String>, int>{}), isEmpty);
    expect(recommendedTagsFrom(<List<String>, int>{<String>[]: 1}), isEmpty);
  });
}
