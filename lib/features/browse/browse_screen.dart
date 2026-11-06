import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cover.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/skeleton.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  String? _sourceId;
  String _query = '';

  final _items = <MangaSummary>[];
  final _animated = <int>{}; // índices que ya hicieron su animación de entrada
  int _page = 0;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0; // descarta respuestas de búsquedas anteriores

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 700) _loadMore();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset(String sourceId) {
    _generation++;
    _sourceId = sourceId;
    _items.clear();
    _animated.clear();
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadMore();
  }

  Future<void> _loadMore() async {
    final sourceId = _sourceId;
    if (sourceId == null || _loading || !_hasNext) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(sourceClientProvider).searchManga(
            sourceId: sourceId,
            query: _query,
            page: _page + 1,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _page++;
        _items.addAll(result.items);
        _hasNext = result.hasNextPage && result.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _pickSource(List<MangaSourceInfo> list) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourceSheet(sources: list, selectedId: _sourceId),
    );
    if (picked != null && picked != _sourceId) _reset(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider);
    return SafeArea(
      bottom: false,
      child: AsyncView(
        value: sources,
        onRetry: () => ref.invalidate(sourcesProvider),
        builder: (list) {
          if (list.isEmpty) return const _NoSources();
          if (_sourceId == null || !list.any((s) => s.id == _sourceId)) {
            final first = list.first.id;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => mounted ? _reset(first) : null);
          }
          final current = list.firstWhere(
            (s) => s.id == _sourceId,
            orElse: () => list.first,
          );
          return CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _header(current, list)),
              ..._resultSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          );
        },
      ),
    );
  }

  Widget _header(MangaSourceInfo current, List<MangaSourceInfo> list) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ).animate().scale(
                    duration: 700.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0, 0),
                  ),
              const SizedBox(width: 10),
              Text('Koma', style: t.displayLarge),
            ],
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.04),
          const SizedBox(height: 4),
          Text('¿Qué leemos hoy?', style: t.bodyMedium?.copyWith(color: c.muted))
              .animate()
              .fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 20),
          _SearchField(
            controller: _controller,
            onSubmit: (v) {
              _query = v.trim();
              if (_sourceId != null) _reset(_sourceId!);
            },
            onClear: () {
              _controller.clear();
              _query = '';
              if (_sourceId != null) _reset(_sourceId!);
            },
          ).animate().fadeIn(delay: 180.ms, duration: 500.ms).slideY(begin: 0.15),
          const SizedBox(height: 14),
          _SourcePill(source: current, onTap: () => _pickSource(list))
              .animate()
              .fadeIn(delay: 260.ms, duration: 500.ms),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  List<Widget> _resultSlivers() {
    if (_items.isEmpty) {
      if (_loading) return [_skeletonGrid()];
      if (_error != null) {
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: ErrorPanel(error: _error!, onRetry: _loadMore),
            ),
          ),
        ];
      }
      return [const SliverToBoxAdapter(child: _EmptyResults())];
    }

    // Si el contenido aún no llena la pantalla no habrá scroll que dispare la carga.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _hasNext &&
          !_loading &&
          _error == null &&
          _scroll.hasClients &&
          _scroll.position.extentAfter < 700) {
        _loadMore();
      }
    });

    // Solo las tarjetas nuevas entran animadas.
    final grid = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childCount: _items.length,
        itemBuilder: (context, i) {
          final firstTime = _animated.add(i);
          return _MangaCard(
            manga: _items[i],
            ratio: _ratioFor(_items[i].title),
            animateIn: firstTime,
            delay: Duration(milliseconds: (i % 8) * 55),
          );
        },
      ),
    );
    return [
      grid,
      SliverToBoxAdapter(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(26),
                  child: Center(child: _Dots()),
                )
              : _error != null
                  ? SizedBox(
                      height: 220,
                      child: ErrorPanel(error: _error!, onRetry: _loadMore),
                    )
                  : const SizedBox(height: 8),
        ),
      ),
    ];
  }

  static double _ratioFor(String title) {
    const ratios = [0.68, 0.8, 0.74, 0.9, 0.7, 0.84];
    var h = 7;
    for (final u in title.codeUnits) {
      h = (h * 17 + u) & 0x7fffffff;
    }
    return ratios[h % ratios.length];
  }

  Widget _skeletonGrid() {
    const ratios = [0.68, 0.84, 0.8, 0.7, 0.74, 0.9];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childCount: 6,
        itemBuilder: (_, i) => AspectRatio(
          aspectRatio: ratios[i],
          child: const Skeleton(),
        ),
      ),
    );
  }
}

class _MangaCard extends StatelessWidget {
  const _MangaCard({
    required this.manga,
    required this.ratio,
    required this.animateIn,
    required this.delay,
  });

  final MangaSummary manga;
  final double ratio;
  final bool animateIn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final card = Pressable(
      onTap: () => context.push(
        '/manga/${Uri.encodeComponent(manga.sourceId)}/${Uri.encodeComponent(manga.id)}',
        extra: manga,
      ),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Cover(
              title: manga.title,
              url: manga.coverUrl,
              heroTag: 'cover-${manga.sourceId}-${manga.id}',
              radius: 22,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Text(
                manga.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium?.copyWith(
                  color: Colors.white,
                  fontFamily: 'Fraunces',
                  fontVariations: const [
                    FontVariation('wght', 700),
                    FontVariation('opsz', 36),
                  ],
                  fontSize: 15,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!animateIn) return card;
    return card
        .animate(delay: delay)
        .fadeIn(duration: 480.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, duration: 560.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.96, 0.96),
          duration: 560.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
      ),
      child: TextField(
        controller: controller,
        style: t.bodyLarge,
        cursorColor: c.accent,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: 'Buscar manga…',
          hintStyle: t.bodyLarge?.copyWith(color: c.muted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: Icon(Icons.search_rounded, color: c.muted),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, v, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: v.text.isEmpty
                  ? const SizedBox(key: ValueKey('e'), width: 48)
                  : IconButton(
                      key: const ValueKey('c'),
                      onPressed: onClear,
                      icon: Icon(Icons.close_rounded, color: c.muted),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source, required this.onTap});

  final MangaSourceInfo source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(source.name,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge?.copyWith(color: c.paper)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  source.language.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more_rounded, size: 18, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceSheet extends StatefulWidget {
  const _SourceSheet({required this.sources, required this.selectedId});

  final List<MangaSourceInfo> sources;
  final String? selectedId;

  @override
  State<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<_SourceSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    final q = _filter.toLowerCase();
    final shown = widget.sources
        .where((s) =>
            q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.language.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: c.line),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Row(
                children: [
                  Text('Fuentes', style: t.headlineSmall),
                  const Spacer(),
                  Text('${shown.length}', style: t.labelMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  style: t.bodyLarge,
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nombre o idioma',
                    hintStyle: t.bodyLarge?.copyWith(color: c.muted),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: c.muted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final s = shown[i];
                  final sel = s.id == widget.selectedId;
                  return Pressable(
                    scale: 0.98,
                    onTap: () => Navigator.pop(context, s.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? c.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(s.name,
                                style: t.titleSmall,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(s.language.toUpperCase(), style: t.labelMedium),
                          if (sel) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.check_circle_rounded,
                                color: c.accent, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: (i % 10) * 25),
                        duration: 300.ms,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
              .scale(
                delay: Duration(milliseconds: i * 140),
                duration: 480.ms,
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.1, 1.1),
                curve: Curves.easeInOut,
              ),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 30),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: c.muted),
          const SizedBox(height: 14),
          Text('Sin resultados', style: t.titleLarge),
          const SizedBox(height: 6),
          Text('Prueba con otra búsqueda o cambia de fuente.',
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _NoSources extends StatelessWidget {
  const _NoSources();

  @override
  Widget build(BuildContext context) {
    final c = context.koma;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration:
                  BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.extension_rounded, size: 38, color: c.accent),
            ).animate().scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.5, 0.5),
                ),
            const SizedBox(height: 22),
            Text('Aún no hay fuentes', style: t.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Importa una extensión en la pestaña Extensiones y confía en ella para empezar a leer.',
              style: t.bodyMedium?.copyWith(color: c.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06),
      ),
    );
  }
}
