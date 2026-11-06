import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';

/// Bloque de carga con brillo que recorre la superficie.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height, this.width, this.radius = 18});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (ctrl) => ctrl.repeat())
        .shimmer(
          duration: 1400.ms,
          color: c.surfaceHigh,
          angle: 0.5,
        );
  }
}
