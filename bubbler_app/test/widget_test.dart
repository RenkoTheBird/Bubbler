import 'package:flutter_test/flutter_test.dart';

import 'package:bubbler_app/app/app.dart';

void main() {
  testWidgets('Phase 0 placeholder shows Bubbler brand', (WidgetTester tester) async {
    await tester.pumpWidget(const BubblerApp());

    expect(find.text('Bubbler'), findsOneWidget);
    expect(find.text('See what you actually care about'), findsOneWidget);
  });
}
