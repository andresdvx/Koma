import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Portada con degradado propio mientras carga o si no hay imagen.
/// El degradado se elige por hash del título, así cada manga conserva su color.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.title,
    this.url,
    this.radius = 18,
    this.heroTag,
    this.fit = BoxFit.cover,
  });

  final String title;
  final String? url;
  final double radius;
  final Object? heroTag;
  final BoxFit fit;

  List<Color> get _gradient {
    final list = KomaColors.coverGradients;
    var h = 0;
    for (final u in title.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return list[h % list.length];
  }

  @override
  Widget build(BuildContext context) {
    final g = _gradient;
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();

    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 64,
              ),
        ),
      ),
    );

    Widget image = placeholder;
    if (url != null && url!.isNotEmpty) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.network(
            url!,
            fit: fit,
            frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
              opacity: frame == null && !sync ? 0 : 1,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              child: child,
            ),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    }

    Widget result = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
    if (heroTag != null) {
      result = Hero(
        tag: heroTag!,
        flightShuttleBuilder: (_, anim, _, _, toCtx) => FadeTransition(
          opacity: anim,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: image,
          ),
        ),
        child: result,
      );
    }
    return result;
  }
}
