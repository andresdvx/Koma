import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/skeleton.dart';

class MangaDetailsScreen extends ConsumerStatefulWidget {
  const MangaDetailsScreen({
    super.key,
    required this.sourceId,
    required this.mangaId,
    this.summary,
  });

  final String sourceId;
  final String mangaId;

  /// Datos ya conocidos del listado: permiten pintar título y portada al instante.
  final MangaSummary? summary;

  @override
  ConsumerState<MangaDetailsScreen> createState() => _MangaDetailsScreenState();
}

class _MangaDetailsScreenState extends ConsumerState<MangaDetailsScreen> {
  bool _descending = true;
  bool _expanded = false;

  LibKey get _libKey => (sourceId: widget.sourceId, mangaId: widget.mangaId);

  String get _mangaTitle {
    final d = ref
        .read(mangaDetailProvider(
            (sourceId: widget.sourceId, mangaId: widget.mangaId)))
        .value;
    return d?.title ?? widget.summary?.title ?? '';
  }

  String? get _mangaCover {
    final d = ref
        .read(mangaDetailProvider(
            (sourceId: widget.sourceId, mangaId: widget.mangaId)))
        .value;
    return d?.coverUrl ?? widget.summary?.coverUrl;
  }

  Future<void> _toggleFavorite(bool inLibrary) async {
    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    if (inLibrary) {
      await db.removeFromLibrary(widget.sourceId, widget.mangaId);
    } else {
      await db.addToLibrary(
        sourceId: widget.sourceId,
        mangaId: widget.mangaId,
        title: _mangaTitle,
        coverUrl: _mangaCover,
      );
    }
  }

  /// Capítulo por el que seguir: el último abierto, o el siguiente si ya lo terminó.
  Chapter? _resumeChapter(
    List<Chapter> list,
    Map<String, ReadingHistoryData> progress,
  ) {
    if (progress.isEmpty || list.isEmpty) return null;
    final byId = {for (final c in list) c.id: c};
    final recent = progress.values.where((h) => byId.containsKey(h.chapterId)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (recent.isEmpty) return null;
    final last = byId[recent.first.chapterId]!;
    if (!recent.first.finished) return last;
    final n = last.number;
    if (n != null) {
      final next = list.where((c) => c.number != null && c.number! > n).toList()
        ..sort((a, b) => a.number!.compareTo(b.number!));
      if (next.isNotEmpty) return next.first;
    }
    return last;
  }

  void _openChapter(Chapter c) {
    HapticFeedback.selectionClick();
    ref.read(databaseProvider).touchChapter(
          sourceId: widget.sourceId,
          mangaId: widget.mangaId,
          mangaTitle: _mangaTitle,
          coverUrl: _mangaCover,
          chapterId: c.id,
          chapterName: c.name,
        );
    context.push(
      '/reader/${Uri.encodeComponent(widget.sourceId)}/${Uri.encodeComponent(c.id)}'
      '?title=${Uri.encodeQueryComponent(c.name)}',
    );
  }

  /// Primer capítulo según numeración; si no hay números, el último de la lista.
  Chapter? _firstChapter(List<Chapter> list) {
    if (list.isEmpty) return null;
    final numbered = list.where((c) => c.number != null).toList();
    if (numbered.isNotEmpty) {
      numbered.sort((a, b) => a.number!.compareTo(b.number!));
      return numbered.first;
    }
    return list.last;
  }

  @override
  Widget build(BuildContext context) {
    final key = (sourceId: widget.sourceId, mangaId: widget.mangaId);
    final detail = ref.watch(mangaDetailProvider(key));
    final chapters = ref.watch(chaptersProvider(key));
    final d = detail.value;
    final title = d?.title ?? widget.summary?.title ?? '';
    final coverUrl = d?.coverUrl ?? widget.summary?.coverUrl;
    final inLibrary = ref.watch(inLibraryProvider(_libKey)).value ?? false;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              heroTag: 'cover-${widget.sourceId}-${widget.mangaId}',
              title: title,
              coverUrl: coverUrl,
              author: d?.author,
              status: d?.status,
              inLibrary: inLibrary,
              onFavorite: () => _toggleFavorite(inLibrary),
            ),
          ),
          SliverToBoxAdapter(child: _body(detail, chapters)),
          ..._chapterSlivers(chapters),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _body(AsyncValue<MangaDetail> detail, AsyncValue<List<Chapter>> chapters) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final d = detail.value;
    if (detail.hasError) {
      return SizedBox(
        height: 220,
        child: ErrorPanel(
          error: detail.error!,
          onRetry: () => ref.invalidate(mangaDetailProvider(
              (sourceId: widget.sourceId, mangaId: widget.mangaId))),
        ),
      );
    }
    if (d == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
        child: Column(
          children: [
            Skeleton(height: 28, radius: 14),
            SizedBox(height: 14),
            Skeleton(height: 90, radius: 18),
          ],
        ),
      );
    }
    final chapterList = chapters.value ?? const <Chapter>[];
    final progress = ref.watch(mangaProgressProvider(_libKey)).value ?? const {};
    final resume = _resumeChapter(chapterList, progress);
    final first = resume ?? _firstChapter(chapterList);
    final desc = (d.description ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.genres.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < d.genres.length; i++)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line),
                    ),
                    child: Text(d.genres[i], style: t.labelMedium),
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 60 * (i % 10)),
                        duration: 350.ms,
                      )
                      .slideY(begin: 0.3, curve: Curves.easeOutCubic),
              ],
            ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  desc,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.fade,
                  style: t.bodyMedium?.copyWith(height: 1.6, color: c.paper.withValues(alpha: 0.86)),
                ),
              ),
            ),
            if (desc.length > 180)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Leer menos' : 'Leer más',
                      style: t.labelLarge?.copyWith(color: c.accent)),
                ),
              ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _CtaButton(
                  label: first == null
                      ? 'Cargando capítulos…'
                      : resume != null
                          ? 'Continuar leyendo'
                          : 'Empezar a leer',
                  sub: first?.name,
                  enabled: first != null,
                  onTap: first == null ? null : () => _openChapter(first),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms, duration: 450.ms).slideY(begin: 0.2),
          const SizedBox(height: 30),
          Row(
            children: [
              Text('Capítulos', style: t.headlineSmall),
              const SizedBox(width: 10),
              if (chapters.value != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${chapters.value!.length}',
                      style: t.labelMedium?.copyWith(color: c.accent)),
                ),
              const Spacer(),
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _descending = !_descending);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line),
                  ),
                  child: AnimatedRotation(
                    turns: _descending ? 0 : 0.5,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.arrow_downward_rounded,
                        size: 18, color: c.paper),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  List<Widget> _chapterSlivers(AsyncValue<List<Chapter>> chapters) {
    if (chapters.hasError) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ErrorPanel(
              error: chapters.error!,
              onRetry: () => ref.invalidate(chaptersProvider(
                  (sourceId: widget.sourceId, mangaId: widget.mangaId))),
            ),
          ),
        ),
      ];
    }
    final list = chapters.value;
    if (list == null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, _) => const Skeleton(height: 66, radius: 20),
          ),
        ),
      ];
    }
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: Text('Esta fuente no tiene capítulos todavía',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
      ];
    }
    final shown = _descending ? list : list.reversed.toList();
    final progress = ref.watch(mangaProgressProvider(_libKey)).value ?? const {};
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        sliver: SliverList.separated(
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ChapterTile(
            chapter: shown[i],
            index: i,
            read: progress[shown[i].id]?.finished ?? false,
            progress: progress[shown[i].id]?.progress ?? 0,
            onTap: () => _openChapter(shown[i]),
          ),
        ),
      ),
    ];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.heroTag,
    required this.title,
    required this.coverUrl,
    required this.author,
    required this.status,
    required this.inLibrary,
    required this.onFavorite,
  });

  final bool inLibrary;
  final VoidCallback onFavorite;
  final String heroTag;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Fondo: portada desenfocada que se funde con el color de fondo.
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null && coverUrl!.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                  child: Image.network(coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.ink.withValues(alpha: 0.35),
                      c.ink.withValues(alpha: 0.78),
                      c.ink,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, top + 64, 22, 26),
          child: Column(
            children: [
              Container(
                width: 168,
                height: 244,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 22),
                    ),
                  ],
                ),
                child: Cover(
                  title: title,
                  url: coverUrl,
                  heroTag: heroTag,
                  radius: 26,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: t.headlineMedium,
              ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.15),
              if ((author ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(author!, style: t.bodyMedium?.copyWith(color: c.muted))
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 450.ms),
              ],
              if ((status ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(status!,
                      style: t.labelMedium?.copyWith(color: c.accent)),
                ).animate().fadeIn(delay: 160.ms, duration: 450.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      curve: Curves.easeOutBack,
                    ),
              ],
            ],
          ),
        ),
        Positioned(
          top: top + 10,
          left: 14,
          child: Pressable(
            onTap: () => context.pop(),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 44,
                  height: 44,
                  color: c.glass,
                  child: Icon(Icons.arrow_back_rounded, color: c.paper),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: top + 10,
          right: 14,
          child: Pressable(
            onTap: onFavorite,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 44,
                  height: 44,
                  color: c.glass,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                    child: Icon(
                      inLibrary
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(inLibrary),
                      color: inLibrary ? c.accent : c.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [c.accent, const Color(0xFFFF8A3D)])
              : null,
          color: enabled ? null : c.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded,
                color: enabled ? Colors.white : c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.titleSmall
                          ?.copyWith(color: enabled ? Colors.white : c.muted)),
                  if (sub != null)
                    Text(sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall
                            ?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.onTap,
    this.read = false,
    this.progress = 0,
  });

  final bool read;
  final double progress;
  final Chapter chapter;
  final int index;
  final VoidCallback onTap;

  String get _number {
    final n = chapter.number;
    if (n == null) return '·';
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  String? get _date {
    final d = chapter.uploadedAt;
    if (d == null) return null;
    final diff = DateTime.now().difference(d);
    if (diff.inDays < 1) return 'Hoy';
    if (diff.inDays < 30) return 'Hace ${diff.inDays} d';
    if (diff.inDays < 365) return 'Hace ${(diff.inDays / 30).floor()} m';
    return 'Hace ${(diff.inDays / 365).floor()} a';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final tile = Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Opacity(
        opacity: read ? 0.55 : 1,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                _number,
                style: t.headlineSmall?.copyWith(color: c.accent, fontSize: 24),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall),
                  if (_date != null) Text(_date!, style: t.bodySmall),
                  if (!read && progress > 0.02)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: c.accent,
                        backgroundColor: c.line,
                      ),
                    ),
                ],
              ),
            ),
            Icon(read ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: read ? c.accent : c.muted),
          ],
        ),
      ),
      ),
    );
    if (index > 14) return tile;
    return tile
        .animate(delay: Duration(milliseconds: 40 * index))
        .fadeIn(duration: 380.ms)
        .slideX(begin: 0.06, curve: Curves.easeOutCubic);
  }
}
