import 'package:flutter/material.dart';

/// Asset-bundled EVE UI icon. The PNGs in `assets/icons/fitting/` are
/// CCP's canonical Show-Info icons (shield, armor, hull, the four
/// damage types, CPU, power grid, …) so the fitting view matches what
/// players expect from the in-game window.
class FittingIcon extends StatelessWidget {
  const FittingIcon({
    super.key,
    required this.name,
    this.size = 18,
    this.color,
  });

  /// File name without extension under `assets/icons/fitting/`.
  /// Examples: `shield`, `armor`, `hull`, `resist_em`, `cpu`,
  /// `powergrid`, `cargo`, `drones`, `capacitor`.
  final String name;
  final double size;

  /// Optional tint. The CCP icons are mostly grayscale so a tint paints
  /// cleanly through `colorFilter` for damage-type accents.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/fitting/$name.png',
      width: size,
      height: size,
      color: color,
      filterQuality: FilterQuality.medium,
    );
  }
}
