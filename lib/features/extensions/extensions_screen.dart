import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/platform/android_source_client.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/pressable.dart';

import 'catalog_view.dart';

/// `true` = muestra el catálogo de repositorios; `false` = extensiones instaladas.
class _CatalogTab extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final _catalogTabProvider = NotifierProvider<_CatalogTab, bool>(
  _CatalogTab.new,
);

typedef ExtensionRow = ({ExtensionInfo info, bool imported});

/// Extensiones importadas en Koma + las instaladas en el teléfono sin importar.
final extensionRowsProvider = FutureProvider<List<ExtensionRow>>((ref) async {
  final client = ref.watch(sourceClientProvider);
  final imported = await client.getExtensions();
  final rows = <ExtensionRow>[
    for (final e in imported) (info: e, imported: true),
  ];
  if (client is AndroidSourceClient) {
    final ids = imported.map((e) => e.id).toSet();
    for (final e in await client.listDeviceExtensions()) {
      if (!ids.contains(e.id)) rows.add((info: e, imported: false));
    }
  }
  return rows;
});

class ExtensionsScreen extends ConsumerWidget {
  const ExtensionsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(AndroidSourceClient c) action,
  ) async {
    final client = ref.read(sourceClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (client is! AndroidSourceClient) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Las extensiones solo están disponibles en Android'),
        ),
      );
      return;
    }
    try {
      await action(client);
    } on KomaError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    ref.invalidate(extensionRowsProvider);
    ref.invalidate(sourcesProvider);
    ref.invalidate(catalogProvider);
  }

  /// Instala/actualiza desde el catálogo y pide confianza si aún no la tiene.
  Future<void> _installFromCatalog(
    BuildContext context,
    WidgetRef ref,
    CatalogEntry entry,
  ) async {
    final client = ref.read(sourceClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (client is! AndroidSourceClient) return;
    List<ExtensionInfo> after;
    try {
      after = await client.installExtension(entry.repo, entry.id);
    } on KomaError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    ref.invalidate(extensionRowsProvider);
    ref.invalidate(catalogProvider);
    final info = after.where((e) => e.id == entry.id).firstOrNull;
    if (info == null || info.trusted) {
      ref.invalidate(sourcesProvider);
      messenger.showSnackBar(SnackBar(content: Text('${entry.name} lista')));
      return;
    }
    if (!context.mounted) return;
    if (await _confirmTrust(context, info) && context.mounted) {
      await _run(context, ref, (c) => c.trustExtension(info.id));
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Instalada sin confiar; actívala desde Instaladas'),
        ),
      );
    }
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    WidgetRef ref,
    ExtensionInfo e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${e.name}?'),
        content: const Text('Se elimina de Koma y se revoca la confianza.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, ref, (c) => c.uninstallExtension(e.id));
    }
  }

  Future<bool> _confirmTrust(BuildContext context, ExtensionInfo e) async {
    HapticFeedback.mediumImpact();
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(
            begin: 0.92,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) {
        final c = ctx.koma;
        final t = Theme.of(ctx).textTheme;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(26),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: c.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_moon_rounded,
                      color: c.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('¿Confiar en ${e.name}?', style: t.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    'Esta extensión (${e.id}) ejecutará código de terceros dentro de '
                    'Koma con acceso a internet. Confía solo si conoces su origen.',
                    style: t.bodyMedium?.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: c.surfaceHigh,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text('Cancelar', style: t.labelLarge),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Pressable(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Confiar',
                              style: t.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(extensionRowsProvider);
    final showCatalog = ref.watch(_catalogTabProvider);
    final t = Theme.of(context).textTheme;
    final c = context.koma;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extensiones',
                  style: t.displayLarge?.copyWith(fontSize: 38),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cada extensión añade fuentes de lectura. Importa y confía solo en las que conozcas.',
                  style: t.bodyMedium?.copyWith(color: c.muted),
                ),
              ],
            ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Instaladas')),
                ButtonSegment(value: true, label: Text('Catálogo')),
              ],
              selected: {showCatalog},
              onSelectionChanged: (s) =>
                  ref.read(_catalogTabProvider.notifier).set(s.first),
            ),
          ),
          Expanded(
            child: showCatalog
                ? CatalogView(
                    onInstall: (e) => _installFromCatalog(context, ref, e),
                  )
                : AsyncView(
                    value: rows,
                    onRetry: () => ref.invalidate(extensionRowsProvider),
                    builder: (list) => list.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron extensiones',
                              style: t.bodyMedium?.copyWith(color: c.muted),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 130),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final r = list[i];
                              return _ExtensionCard(
                                    row: r,
                                    onLongPress: r.imported
                                        ? () => _confirmUninstall(
                                            context,
                                            ref,
                                            r.info,
                                          )
                                        : null,
                                    onImport: () => _run(
                                      context,
                                      ref,
                                      (c) => c.importDeviceExtension(r.info.id),
                                    ),
                                    onTrust: () async {
                                      if (await _confirmTrust(
                                            context,
                                            r.info,
                                          ) &&
                                          context.mounted) {
                                        await _run(
                                          context,
                                          ref,
                                          (c) => c.trustExtension(r.info.id),
                                        );
                                      }
                                    },
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: 60 * i),
                                    duration: 420.ms,
                                  )
                                  .slideY(
                                    begin: 0.12,
                                    curve: Curves.easeOutCubic,
                                  );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({
    required this.row,
    required this.onImport,
    required this.onTrust,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;
  final ExtensionRow row;
  final VoidCallback onImport;
  final VoidCallback onTrust;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final info = row.info;
    final grad =
        KomaColors.coverGradients[info.id.hashCode.abs() %
            KomaColors.coverGradients.length];
    final trusted = row.imported && info.trusted;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: trusted ? c.accent.withValues(alpha: 0.5) : c.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: grad,
                ),
              ),
              child: Text(
                info.name.isEmpty ? '?' : info.name[0].toUpperCase(),
                style: t.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: t.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'v${info.version} · ${info.language.toUpperCase()}',
                    style: t.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.id,
                    style: t.bodySmall?.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              child: !row.imported
                  ? _Action(
                      key: const ValueKey('import'),
                      label: 'Importar',
                      filled: false,
                      onTap: onImport,
                    )
                  : trusted
                  ? Container(
                      key: const ValueKey('ok'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        color: c.accent,
                        size: 24,
                      ),
                    )
                  : _Action(
                      key: const ValueKey('trust'),
                      label: 'Confiar',
                      filled: true,
                      onTap: onTrust,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? c.accent : c.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: filled ? Colors.white : c.paper),
        ),
      ),
    );
  }
}
