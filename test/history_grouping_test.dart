import 'package:flutter_test/flutter_test.dart';
import 'package:webtoon_flutter_pab2/screens/history_screen.dart';

void main() {
  test('groups reading history by title and keeps episode entries', () {
    final grouped = groupHistoryEntries([
      {
        'title': 'Solo Leveling',
        'episode': 'Episode 1',
        'timestamp': '2026-06-17T10:00:00.000'
      },
      {
        'title': 'Solo Leveling',
        'episode': 'Episode 2',
        'timestamp': '2026-06-17T11:00:00.000'
      },
      {
        'title': 'Solo Leveling',
        'episode': 'Episode 3',
        'timestamp': '2026-06-17T12:00:00.000'
      },
    ]);

    expect(grouped.length, 1);
    expect(grouped.first['title'], 'Solo Leveling');
    expect((grouped.first['episodes'] as List).length, 3);
  });
}
