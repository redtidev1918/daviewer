import 'package:daviewer/features/artist/artist_journals_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatJournalDate formats as YYYY-MM-DD', () {
    expect(formatJournalDate(DateTime(2024, 5, 3)), '2024-05-03');
    expect(formatJournalDate(DateTime(2024, 11, 9)), '2024-11-09');
  });
}
