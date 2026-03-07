import 'package:flutter/material.dart';

// The namenu+ logo icon, tinted to match the current accent color.
// Uses a ColorFiltered widget with hue/saturation/brightness blending
// so the icon always matches whatever accent the user has picked.
//
// Usage:
//   AppLogo(size: 48)
//   AppLogo(size: 24, color: Colors.white)

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color; // override color, otherwise uses accent from theme

  const AppLogo({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return ColorFiltered(
      // srcATop blends the tint color onto the icon while preserving its shape/alpha
      colorFilter: ColorFilter.mode(tint, BlendMode.srcATop),
      child: Image.asset(
        'assets/icon.png',
        width:  size,
        height: size,
        // fallback: if icon asset isn't loaded yet, show a placeholder
        errorBuilder: (_, __, ___) => Icon(
          Icons.restaurant_rounded,
          size:  size,
          color: tint,
        ),
      ),
    );
  }
}