import 'package:flutter_test/flutter_test.dart';
import 'package:daviewer/main.dart';

void main() {
  testWidgets('shows client id hint when unconfigured', (WidgetTester tester) async {
    await tester.pumpWidget(const DeviantArtClientApp());
    await tester.pump();
    expect(find.text('Pass DAKIT_CLIENT_ID at build time.'), findsOneWidget);
  });
}
