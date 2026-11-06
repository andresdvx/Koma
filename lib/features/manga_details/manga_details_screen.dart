import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';

class MangaDetailsScreen extends ConsumerWidget {
  const MangaDetailsScreen({
    super.key,
    required this.sourceId,
    required this.mangaId,
  });

  final String sourceId;
  final String mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceId: sourceId, mangaId: mangaId);
    final detail = ref.watch(mangaDetailProvider(key));
    final chapters = ref.watch(chaptersProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.title ?? 'Detalles')),
      body: AsyncView(
        value: detail,
        onRetry: () => ref.invalidate(mangaDetailProvider(key)),
        builder: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(m.title, style: Theme.of(context).textTheme.headlineSmall),
            if (m.author != null) Text(m.author!),
            if (m.status != null) Text(m.status!),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final g in m.genres) Chip(label: Text(g)),
            ]),
            if (m.description != null) ...[
              const SizedBox(height: 8),
              Text(m.description!),
            ],
            const Divider(height: 32),
            Text('Capítulos', style: Theme.of(context).textTheme.titleMedium),
            AsyncView(
              value: chapters,
              onRetry: () => ref.invalidate(chaptersProvider(key)),
              builder: (list) => Column(
                children: [
                  for (final c in list)
                    ListTile(
                      title: Text(c.name),
                      // El lector llega en la fase 3.
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
