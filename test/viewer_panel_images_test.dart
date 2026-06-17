import 'package:flutter_test/flutter_test.dart';
import 'package:webtoon_flutter_pab2/screens/viewer_screen.dart';

void main() {
  test('viewer panel sources reuse the selected webtoon cover when available', () {
    final sources = buildViewerPanelSources(
      coverImage: 'the_secret_of_angel.jpeg',
      title: 'The Secret of Angel',
      episodeTitle: 'Episode 1',
    );

    expect(sources.length, 5);
    expect(
      sources.every(
        (source) => source == 'the_secret_of_angel.jpeg' || source.startsWith('assets/images/'),
      ),
      isTrue,
    );
  });
}
