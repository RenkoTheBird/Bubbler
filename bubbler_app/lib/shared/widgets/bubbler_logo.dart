import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Bubble cluster logo matching Swift `BubblerLogoView`.
class BubblerLogo extends StatelessWidget {
  const BubblerLogo({super.key, this.size = 180});

  /// Outer frame size. Bubble offsets/diameters scale from a 180pt design.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = size / 180;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  BubblerTheme.cyan.withValues(alpha: 0.25),
                  BubblerTheme.blue.withValues(alpha: 0.15),
                  BubblerTheme.blue.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          _Bubble(x: -25, y: -30, diameter: 38, opacity: 0.9, scale: scale),
          _Bubble(x: 15, y: -45, diameter: 22, opacity: 0.7, scale: scale),
          _Bubble(x: 35, y: -10, diameter: 26, opacity: 0.75, scale: scale),
          _Bubble(x: -35, y: 15, diameter: 30, opacity: 0.8, scale: scale),
          _Bubble(x: 10, y: 25, diameter: 40, opacity: 0.85, scale: scale),
          _Bubble(x: 45, y: 35, diameter: 20, opacity: 0.65, scale: scale),
          _Bubble(x: -10, y: 55, diameter: 24, opacity: 0.7, scale: scale),
          _Bubble(
            x: 5,
            y: 5,
            diameter: 18,
            opacity: 1.0,
            scale: scale,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.x,
    required this.y,
    required this.diameter,
    required this.opacity,
    required this.scale,
    this.highlight = false,
  });

  final double x;
  final double y;
  final double diameter;
  final double opacity;
  final double scale;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final size = diameter * scale;

    return Transform.translate(
      offset: Offset(x * scale, y * scale),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: opacity),
              BubblerTheme.cyan.withValues(alpha: opacity * 0.6),
              BubblerTheme.blue.withValues(alpha: opacity * 0.8),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: BubblerTheme.blue.withValues(alpha: 0.15),
              blurRadius: 4 * scale,
            ),
            if (highlight)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 6 * scale,
              ),
          ],
        ),
      ),
    );
  }
}
