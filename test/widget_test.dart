import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenTrackApp());
    expect(find.text('OpenTrack'), findsOneWidget);
  });
}
