import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether [context]'s theme (or [defaultTargetPlatform]) expects Cupertino chrome.
bool isCupertinoPlatform([BuildContext? context]) {
  final platform =
      context != null ? Theme.of(context).platform : defaultTargetPlatform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}
