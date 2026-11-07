import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/pressable.dart';

void _openManga(BuildContext context, MangaSummary m) => context.push(
      '/manga/${Uri.encodeComponent(m.sourceId)}/${Uri.encodeComponent(m.id)}',
      extra: m,
    );

/// Biblioteca: seguir leyendo + mangas guardados.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = context.koma;
    final library = ref.watch(libraryProvider);
    final recent = ref.watch(recentReadsProvider).value ?? const [];
    return SafeArea(
      bottom: false,
      child: AsyncView(
        value: library,
        onRetry: () => ref.invalidate(libraryProvider),
        builder: (entries) {
          if (entries.isEmpty && recent.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 46, color: c.muted),
                    const SizedBox(height: 16),
                    Text('Tu biblioteca está vacía', style: t.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el corazón en un manga para guardarlo aquí. '
                      'Lo que leas aparecerá en "Seguir leyendo".',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                  child: Text('Biblioteca',
                          style: t.displayLarge?.copyWith(fontSize: 38))
                      .animate()
                      .fadeIn(duration: 450.ms)
                      .slideY(begin: 0.08),
                ),
              ),
              if (recent.isNotEmpty) ...[
                _sectionTitle(context, 'Seguir leyendo'),
                SliverToBoxAdapter(child: _RecentRow(items: recent)),
              ],
              if (entries.isNotEmpty) ...[
                _sectionTitle(context, 'Guardados (${entries.length})'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _LibraryCard(entry: entries[i]),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _sectionTitle(BuildContext context, String text) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
          child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
        ),
      );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.items});

  final List<ReadingHistoryData> items;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final h = items[i];
          return Pressable(
            onTap: () => _openManga(
              context,
              MangaSummary(
                sourceId: h.sourceId,
                id: h.mangaId,
                title: h.mangaTitle,
                coverUrl: h.coverUrl,
              ),
            ),
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Cover(title: h.mangaTitle, url: h.coverUrl, radius: 20),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: h.finished ? 1 : h.progress,
                              minHeight: 4,
                              color: c.accent,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(h.mangaTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall),
                  Text(h.chapterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => _openManga(
        context,
        MangaSummary(
          sourceId: entry.sourceId,
          id: entry.mangaId,
          title: entry.title,
          coverUrl: entry.coverUrl,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Cover(
              title: entry.title,
              url: entry.coverUrl,
              radius: 18,
              heroTag: 'cover-${entry.sourceId}-${entry.mangaId}',
            ),
          ),
          const SizedBox(height: 6),
          Text(entry.title,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ),
    );
  }
}
