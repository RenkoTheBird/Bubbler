import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'is_cupertino.dart';

/// Activity indicator — Cupertino spinner on iOS/macOS, Material elsewhere.
class AdaptiveProgressIndicator extends StatelessWidget {
  const AdaptiveProgressIndicator({
    super.key,
    this.color,
    this.strokeWidth = 2.0,
    this.radius = 10.0,
  });

  final Color? color;
  final double strokeWidth;

  /// Used on Cupertino; ignored on Material (size via parent [SizedBox]).
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoPlatform(context)) {
      return CupertinoActivityIndicator(
        color: color,
        radius: radius,
      );
    }
    return CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
  }
}
