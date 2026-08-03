import 'package:bubbler_app/app/theme.dart';
import 'package:bubbler_app/shared/platform/platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCupertinoPlatform', () {
    testWidgets('is true on iOS theme platform', (tester) async {
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) {
              result = isCupertinoPlatform(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, isTrue);
    });

    testWidgets('is false on Android theme platform', (tester) async {
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) {
              result = isCupertinoPlatform(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, isFalse);
    });
  });

  group('showAdaptiveAlertDialog', () {
    testWidgets('shows CupertinoAlertDialog on iOS', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.iOS,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveAlertDialog<String>(
                    context: context,
                    title: 'Edit post',
                    message: 'Body',
                    actions: const [
                      AdaptiveDialogAction(label: 'Cancel'),
                      AdaptiveDialogAction(
                        label: 'Save',
                        result: 'saved',
                        isDefaultAction: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Edit post'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('shows AlertDialog on Android', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveAlertDialog<String>(
                    context: context,
                    title: 'Edit post',
                    message: 'Body',
                    actions: const [
                      AdaptiveDialogAction(label: 'Cancel'),
                      AdaptiveDialogAction(
                        label: 'Save',
                        result: 'saved',
                        isDefaultAction: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });

  group('showAdaptiveActionSheet', () {
    testWidgets('shows CupertinoActionSheet on iOS', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.iOS,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveActionSheet<String>(
                    context: context,
                    title: 'Sports',
                    message: 'Update preferences',
                    actions: const [
                      AdaptiveSheetAction(label: 'Prefer Topic', value: 'prefer'),
                      AdaptiveSheetAction(
                        label: 'Blacklist Topic',
                        value: 'blacklist',
                        isDestructive: true,
                      ),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Prefer Topic'), findsOneWidget);
    });

    testWidgets('shows modal bottom sheet on Android', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveActionSheet<String>(
                    context: context,
                    title: 'Sports',
                    message: 'Update preferences',
                    actions: const [
                      AdaptiveSheetAction(label: 'Prefer Topic', value: 'prefer'),
                    ],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Prefer Topic'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('showAdaptiveDatePicker', () {
    testWidgets('shows CupertinoDatePicker on iOS', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.iOS,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveDatePicker(
                    context: context,
                    initialDate: DateTime(2000, 1, 15),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2010),
                    helpText: 'Date of birth',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows Material date picker on Android', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAdaptiveDatePicker(
                    context: context,
                    initialDate: DateTime(2000, 1, 15),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2010),
                    helpText: 'Date of birth',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('Date of birth'), findsOneWidget);
    });
  });

  group('AdaptiveProgressIndicator', () {
    testWidgets('uses CupertinoActivityIndicator on iOS', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.iOS,
          child: const AdaptiveProgressIndicator(color: Colors.white),
        ),
      );

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('uses CircularProgressIndicator on Android', (tester) async {
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.android,
          child: const AdaptiveProgressIndicator(color: Colors.white),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });
  });

  group('adaptivePageRoute', () {
    testWidgets('returns CupertinoPageRoute on iOS', (tester) async {
      late Route<void> route;
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.iOS,
          child: Builder(
            builder: (context) {
              route = adaptivePageRoute<void>(
                context: context,
                builder: (_) => const SizedBox.shrink(),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(route, isA<CupertinoPageRoute<void>>());
    });

    testWidgets('returns MaterialPageRoute on Android', (tester) async {
      late Route<void> route;
      await tester.pumpWidget(
        _harness(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (context) {
              route = adaptivePageRoute<void>(
                context: context,
                builder: (_) => const SizedBox.shrink(),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(route, isA<MaterialPageRoute<void>>());
    });
  });
}

Widget _harness({
  required TargetPlatform platform,
  required Widget child,
}) {
  return MaterialApp(
    theme: BubblerTheme.light().copyWith(platform: platform),
    home: Scaffold(body: child),
  );
}
