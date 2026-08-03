import 'package:flutter/material.dart';

import '../platform/platform.dart';

/// Loading / empty / error state card shared by graph, feed, and search —
/// extracted from Swift `stateCard(title:message:showsProgress:)`.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.title,
    required this.message,
    this.showsProgress = false,
    this.child,
  });

  /// Loading state with spinner.
  factory AsyncBody.loading({
    required String title,
    required String message,
  }) {
    return AsyncBody(
      title: title,
      message: message,
      showsProgress: true,
    );
  }

  /// Empty / idle state without spinner.
  factory AsyncBody.empty({
    required String title,
    required String message,
  }) {
    return AsyncBody(
      title: title,
      message: message,
    );
  }

  final String title;
  final String message;
  final bool showsProgress;

  /// When non-null, replaces the default card (useful for success bodies).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (showsProgress) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: AdaptiveProgressIndicator(
                    strokeWidth: 2,
                    radius: 9,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
