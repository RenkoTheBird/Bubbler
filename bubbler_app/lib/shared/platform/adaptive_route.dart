import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'is_cupertino.dart';

/// Page route — Cupertino slide on iOS/macOS, Material elsewhere.
Route<T> adaptivePageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
  String? title,
}) {
  if (isCupertinoPlatform(context)) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
      title: title,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}
