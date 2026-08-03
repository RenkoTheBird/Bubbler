import 'package:flutter/material.dart';

/// Labeled 0…1 slider with percent readout — Swift `PreferenceSliderRow`.
class PreferenceSlider extends StatelessWidget {
  const PreferenceSlider({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.tint,
    this.isDisabled = false,
  });

  final String title;
  final double value;
  final ValueChanged<double>? onChanged;
  final Color tint;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();

    return Opacity(
      opacity: isDisabled ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: tint,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
              thumbColor: tint,
              overlayColor: tint.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: isDisabled ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
