import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'is_cupertino.dart';

/// Platform-agnostic alert action. Tapping pops with [result] or [resultBuilder].
class AdaptiveDialogAction<T> {
  const AdaptiveDialogAction({
    required this.label,
    this.result,
    this.resultBuilder,
    this.isDestructive = false,
    this.isDefaultAction = false,
  });

  final String label;
  final T? result;
  final T? Function()? resultBuilder;
  final bool isDestructive;
  final bool isDefaultAction;

  T? resolve() => resultBuilder?.call() ?? result;
}

/// Platform-agnostic action-sheet row.
class AdaptiveSheetAction<T> {
  const AdaptiveSheetAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
    this.icon,
  });

  final String label;
  final T value;
  final bool isDestructive;
  final IconData? icon;
}

/// Alert dialog — Cupertino on iOS/macOS, Material elsewhere.
Future<T?> showAdaptiveAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  required List<AdaptiveDialogAction<T>> actions,
}) {
  assert(
    message == null || content == null,
    'Pass message or content, not both.',
  );

  if (isCupertinoPlatform(context)) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: content ??
              (message == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(message),
                    )),
          actions: [
            for (final action in actions)
              CupertinoDialogAction(
                isDestructiveAction: action.isDestructive,
                isDefaultAction: action.isDefaultAction,
                onPressed: () =>
                    Navigator.of(dialogContext).pop(action.resolve()),
                child: Text(action.label),
              ),
          ],
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: BubblerTheme.deepBlue,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: content ??
            (message == null
                ? null
                : Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  )),
        actions: [
          for (final action in actions)
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(action.resolve()),
              style: TextButton.styleFrom(
                foregroundColor: action.isDestructive
                    ? Colors.redAccent.shade100
                    : Colors.white,
              ),
              child: Text(
                action.label,
                style: TextStyle(
                  fontWeight:
                      action.isDefaultAction ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Action sheet — CupertinoActionSheet on iOS/macOS, modal bottom sheet elsewhere.
Future<T?> showAdaptiveActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<AdaptiveSheetAction<T>> actions,
  String cancelLabel = 'Cancel',
}) {
  if (isCupertinoPlatform(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: title == null ? null : Text(title),
          message: message == null ? null : Text(message),
          actions: [
            for (final action in actions)
              CupertinoActionSheetAction(
                isDestructiveAction: action.isDestructive,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(action.value),
                child: Text(action.label),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelLabel),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: BubblerTheme.deepBlue,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              ListTile(
                title: title == null
                    ? null
                    : Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                subtitle: message == null
                    ? null
                    : Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
              ),
            for (final action in actions)
              ListTile(
                leading: action.icon == null
                    ? null
                    : Icon(
                        action.icon,
                        color: action.isDestructive
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive
                        ? Colors.redAccent.shade100
                        : Colors.white,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
            ListTile(
              title: Text(
                cancelLabel,
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
}

/// Transient message — Cupertino alert on iOS/macOS, SnackBar elsewhere.
Future<void> showAdaptiveMessage(
  BuildContext context,
  String message, {
  String title = 'Bubbler',
}) async {
  if (isCupertinoPlatform(context)) {
    await showAdaptiveAlertDialog<void>(
      context: context,
      title: title,
      message: message,
      actions: const [
        AdaptiveDialogAction(label: 'OK', isDefaultAction: true),
      ],
    );
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
