import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bubbler_app/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Auth gate shows login when signed out', (tester) async {
    await tester.pumpWidget(const BubblerApp());
    await tester.pumpAndSettle();

    expect(find.text('Bubbler'), findsOneWidget);
    expect(find.text('See what you actually care about'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
