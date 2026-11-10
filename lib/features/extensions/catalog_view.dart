import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/platform/android_source_client.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/pressable.dart';

AndroidSourceClient? _android(Ref ref) {
  final c = ref.watch(sourceClientProvider);
  return c is AndroidSourceClient ? c : null;
}

final repositoriesProvider = FutureProvider<List<String>>((ref) async {
  return await _android(ref)?.getRepositories() ?? const [];
});

final catalogProvider = FutureProvider<List<CatalogEntry>>((ref) async {
  final c = _android(ref);
  if (c == null) return const [];
  ref.watch(repositoriesProvider);
  return c.getCatalog();
});

/// Catálogo de extensiones de los repositorios configurados.
class CatalogView extends ConsumerStatefulWidget {
  const CatalogView({super.key, required this.onInstall});

  /// Instala o actualiza; quien llama decide cómo pedir confianza después.
  final Future<void> Function(CatalogEntry entry) onInstall;

  @override
  ConsumerState<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends ConsumerState<CatalogView> {
  String _query = '';
  final _busy = <String>{};

  Future<void> _install(CatalogEntry e) async {
    setState(() => _busy.add(e.id));
    try {
      await widget.onInstall(e);
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  Future<void> _manageRepos() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // por encima del dock flotante
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: context.koma.surface,
      builder: (_) => const _ReposSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final catalog = ref.watch(catalogProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar extensión o idioma (es, en…)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Repositorios',
                onPressed: _manageRepos,
                icon: const Icon(Icons.dns_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: catalog,
            onRetry: () => ref.invalidate(catalogProvider),
            builder: (all) {
              final list =
                  all
                      .where(
                        (e) =>
                            _query.isEmpty ||
                            e.name.toLowerCase().contains(_query) ||
                            e.language.toLowerCase() == _query,
                      )
                      .toList()
                    ..sort((a, b) {
                      int rank(CatalogEntry e) =>
                          e.status == CatalogStatus.update
                          ? 0
                          : e.status == CatalogStatus.available
                          ? 1
                          : 2;
                      final r = rank(a).compareTo(rank(b));
                      return r != 0 ? r : a.name.compareTo(b.name);
                    });
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'Sin resultados',
                    style: t.bodyMedium?.copyWith(color: c.muted),
                  ),
                );
              }
              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 130),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CatalogCard(
                  entry: list[i],
                  busy: _busy.contains(list[i].id),
                  onInstall: () => _install(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.entry,
    required this.busy,
    required this.onInstall,
  });

  final CatalogEntry entry;
  final bool busy;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final e = entry;
    final label = switch (e.status) {
      CatalogStatus.available => 'Instalar',
      CatalogStatus.update => 'Actualizar',
      CatalogStatus.installed => 'Instalada',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: t.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'v${e.version} · ${e.language.toUpperCase()}${e.nsfw ? ' · +18' : ''}',
                  style: t.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else if (e.status == CatalogStatus.installed)
            Text(label, style: t.labelMedium?.copyWith(color: c.muted))
          else
            Pressable(
              onTap: onInstall,
              haptic: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: e.status == CatalogStatus.update
                      ? c.accent
                      : c.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: t.labelLarge?.copyWith(
                    color: e.status == CatalogStatus.update
                        ? Colors.white
                        : c.paper,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReposSheet extends ConsumerStatefulWidget {
  const _ReposSheet();

  @override
  ConsumerState<_ReposSheet> createState() => _ReposSheetState();
}

class _ReposSheetState extends ConsumerState<_ReposSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Ejecuta una operación sobre los repositorios; `action` devuelve el mensaje
  /// que se muestra al usuario (siempre hay respuesta visible, éxito o error).
  Future<void> _change(
    Future<String> Function(AndroidSourceClient c) action,
  ) async {
    final client = ref.read(sourceClientProvider);
    if (client is! AndroidSourceClient || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final message = await action(client);
      if (!mounted) return;
      setState(() => _info = message);
      _ctrl.clear();
    } on KomaError catch (e) {
      if (mounted) {
        setState(() => _error = e.message.isEmpty ? '$e' : e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(repositoriesProvider);
    ref.invalidate(catalogProvider);
  }

  Future<String> _add(AndroidSourceClient c, String url) async =>
      (await c.addRepository(url)).message;

  Future<String> _remove(AndroidSourceClient c, String url) async {
    await c.removeRepository(url);
    return 'Repositorio eliminado';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.koma;
    final repos = ref.watch(repositoriesProvider).asData?.value ?? const [];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repositorios', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Solo HTTPS. Añade únicamente repositorios en los que confíes: '
              'publican código que se ejecuta en Koma.',
              style: t.bodySmall?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: 'URL del repositorio o de su página',
                helperText:
                    'Acepta la carpeta del repositorio, su index.min.json, '
                    'una página de GitHub o un enlace mihon://add-repo',
                helperMaxLines: 3,
                errorText: _error,
                errorMaxLines: 5,
                suffixIcon: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Añadir',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => _change((c) => _add(c, _ctrl.text)),
                      ),
              ),
              onSubmitted: (v) => _change((c) => _add(c, v)),
            ),
            if (_info != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _info!,
                  style: t.bodySmall?.copyWith(color: c.accent),
                ),
              ),
            const SizedBox(height: 18),
            for (final r in repos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(r, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _change((c) => _remove(c, r)),
                ),
              ),
            if (repos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin repositorios', style: t.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
