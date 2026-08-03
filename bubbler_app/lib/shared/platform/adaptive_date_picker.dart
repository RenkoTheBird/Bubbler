import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'is_cupertino.dart';

/// Date picker — Cupertino wheel on iOS/macOS, Material calendar elsewhere.
Future<DateTime?> showAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Select date',
}) async {
  final clampedInitial = _clampDate(initialDate, firstDate, lastDate);

  if (isCupertinoPlatform(context)) {
    var selected = clampedInitial;
    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(sheetContext).pop(
                        DateTime(selected.year, selected.month, selected.day),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: clampedInitial,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  return showDatePicker(
    context: context,
    initialDate: clampedInitial,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: BubblerTheme.cyan,
            onPrimary: Colors.white,
            surface: BubblerTheme.deepBlue,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      );
    },
  );
}

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}
