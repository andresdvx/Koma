import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'pressable.dart';

/// Muestra carga / error con reintento / datos. Los errores nunca cierran la app.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(
        key: ValueKey(value.isLoading
            ? 'loading'
            : value.hasError
                ? 'error'
                : 'data'),
        child: value.when(
          skipLoadingOnReload: true,
          data: builder,
          loading: () => loading ?? const _Loading(),
          error: (e, _) => ErrorPanel(error: e, onRetry: onRetry),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          color: context.koma.accent,
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, color: c.accent, size: 30),
            ).animate().scale(
                  begin: const Offset(0.6, 0.6),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 18),
            Text('Algo salió mal', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: t.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              Pressable(
                onTap: onRetry,
                haptic: true,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('Reintentar',
                      style: t.labelLarge?.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ],
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
      ),
    );
  }
}
