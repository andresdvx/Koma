import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../core/platform/android_source_client.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';

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
      messenger.showSnackBar(const SnackBar(
          content: Text('Las extensiones solo están disponibles en Android')));
      return;
    }
    try {
      await action(client);
    } on KomaError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    ref.invalidate(extensionRowsProvider);
    ref.invalidate(sourcesProvider);
  }

  Future<bool> _confirmTrust(BuildContext context, ExtensionInfo e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Confiar en ${e.name}?'),
        content: Text(
          'Esta extensión (${e.id}) ejecutará código de terceros dentro de '
          'Koma con acceso a internet. Confía solo si conoces su origen.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confiar')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(extensionRowsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Extensiones')),
      body: AsyncView(
        value: rows,
        onRetry: () => ref.invalidate(extensionRowsProvider),
        builder: (list) => list.isEmpty
            ? const Center(child: Text('No se encontraron extensiones'))
            : ListView(
                children: [
                  for (final r in list)
                    ListTile(
                      title: Text(r.info.name),
                      subtitle: Text(
                          '${r.info.id}\nv${r.info.version} · ${r.info.language}'),
                      isThreeLine: true,
                      trailing: !r.imported
                          ? FilledButton.tonal(
                              onPressed: () => _run(context, ref,
                                  (c) => c.importDeviceExtension(r.info.id)),
                              child: const Text('Importar'),
                            )
                          : r.info.trusted
                              ? const Icon(Icons.verified, color: Colors.green)
                              : FilledButton(
                                  onPressed: () async {
                                    if (await _confirmTrust(context, r.info) &&
                                        context.mounted) {
                                      await _run(context, ref,
                                          (c) => c.trustExtension(r.info.id));
                                    }
                                  },
                                  child: const Text('Confiar'),
                                ),
                    ),
                ],
              ),
      ),
    );
  }
}
