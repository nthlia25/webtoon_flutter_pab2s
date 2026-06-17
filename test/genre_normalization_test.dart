import 'package:flutter_test/flutter_test.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';

void main() {
  test('genre normalization keeps labels consistent for uploaded genres', () {
    expect(normalizeGenre('Slice of Life'), 'slice of life');
    expect(normalizeGenre('  Horror  '), 'horror');
    expect(normalizeGenre('SCI-FI'), 'sci-fi');
  });
}
