import 'package:flutter/material.dart';

/// Inline status/error banner used on graph/feed — extracted from Swift
/// `GraphFeedView.banner(_:tint:)`.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.tint,
  });

  /// Convenience for cyan status messages.
  factory StatusBanner.status(String message) {
    return StatusBanner(
      message: message,
      tint: Colors.cyan.withValues(alpha: 0.85),
    );
  }

  /// Convenience for red error messages.
  factory StatusBanner.error(String message) {
    return StatusBanner(
      message: message,
      tint: Colors.red.withValues(alpha: 0.8),
    );
  }

  final String message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}
