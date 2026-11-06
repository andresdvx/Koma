import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  String? _sourceId;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar')),
      body: AsyncView(
        value: sources,
        onRetry: () => ref.invalidate(sourcesProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No hay fuentes disponibles'));
          }
          final sourceId = _sourceId ?? list.first.id;
          final results =
              ref.watch(searchProvider((sourceId: sourceId, query: _query)));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: sourceId,
                      items: [
                        for (final s in list)
                          DropdownMenuItem(
                              value: s.id, child: Text('${s.name} (${s.language})')),
                      ],
                      onChanged: (v) => setState(() => _sourceId = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Buscar manga',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncView(
                  value: results,
                  onRetry: () => ref.invalidate(searchProvider),
                  builder: (page) => page.items.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView(
                          children: [
                            for (final m in page.items)
                              ListTile(
                                title: Text(m.title),
                                onTap: () => context.push(
                                    '/manga/${Uri.encodeComponent(m.sourceId)}/${Uri.encodeComponent(m.id)}'),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
