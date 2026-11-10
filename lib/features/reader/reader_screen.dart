import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/skeleton.dart';

typedef ChapterKey = ({String sourceId, String chapterId});

final pagesProvider = FutureProvider.autoDispose
    .family<List<ReaderPage>, ChapterKey>((ref, k) {
      return ref
          .watch(sourceClientProvider)
          .getPages(sourceId: k.sourceId, chapterId: k.chapterId);
    });

typedef PageKey = ({String sourceId, String chapterId, int index});

/// Bytes de cada página, descargados por el motor.
final pageImageProvider = FutureProvider.autoDispose.family<Uint8List, PageKey>(
  (ref, k) {
    // Mantiene la imagen unos segundos tras salir de pantalla (scroll de ida y vuelta)
    // y luego la libera: la memoria queda acotada a las páginas cercanas.
    final link = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() => timer = Timer(const Duration(seconds: 45), link.close));
    ref.onResume(() => timer?.cancel());
    ref.onDispose(() => timer?.cancel());
    return ref
        .watch(sourceClientProvider)
        .getPageImage(
          sourceId: k.sourceId,
          chapterId: k.chapterId,
          pageIndex: k.index,
        );
  },
);

/// Lector vertical continuo. No conoce el origen de las páginas: solo índices.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.sourceId,
    required this.chapterId,
    this.title,
  });

  final String sourceId;
  final String chapterId;
  final String? title;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _itemScroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _progress = ValueNotifier<double>(0);
  bool _chrome = true;
  Timer? _hideTimer;

  late final AppDatabase _db;
  int _count = 0;
  int _startIndex = 0; // posición guardada: página y desplazamiento
  double _startAlign = 0;
  bool _loaded = false; // historial leído: ya se puede construir la lista
  bool _userMoved = false;
  int _pageIndex = 0;
  double _pageAlign = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _db = ref.read(databaseProvider);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _positions.itemPositions.addListener(_onScroll);
    _scheduleHide();
    _db.historyOf(widget.sourceId, widget.chapterId).then((h) {
      if (!mounted) return;
      // Un capítulo terminado se relee desde el inicio.
      if (h != null && !h.finished && h.progress > 0.01) {
        _startIndex = h.pageIndex;
        _startAlign = h.pageAlign;
        _pageIndex = h.pageIndex;
        _pageAlign = h.pageAlign;
        _progress.value = h.progress;
      }
      setState(() => _loaded = true);
    });
  }

  void _persist() {
    if (!_userMoved || _count == 0) return;
    _db.saveProgress(
      widget.sourceId,
      widget.chapterId,
      _progress.value,
      pageIndex: _pageIndex,
      pageAlign: _pageAlign,
    );
  }

  @override
  void dispose() {
    _persist();
    _positions.itemPositions.removeListener(_onScroll);
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    _progress.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onScroll() {
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0)
        .toList();
    if (visible.isEmpty || _count == 0) return;
    final first = visible.reduce((a, b) => a.index < b.index ? a : b);
    final span = first.itemTrailingEdge - first.itemLeadingEdge;
    final within = span <= 0
        ? 0.0
        : ((-first.itemLeadingEdge) / span).clamp(0.0, 1.0);
    final align = first.itemLeadingEdge;
    final moved =
        first.index != _pageIndex || (align - _pageAlign).abs() > 0.001;
    _pageIndex = first.index;
    _pageAlign = align;
    _progress.value = ((first.index + within) / _count).clamp(0.0, 1.0);
    // Llegar a la última página visible cuenta como fin del capítulo.
    final last = visible.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    if (last == _count - 1 && first.index >= _count - 1) _progress.value = 1;
    if (!moved) return;
    _userMoved = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _persist);
    // Al desplazarse se ocultan los controles para no tapar la página.
    if (_chrome) setState(() => _chrome = false);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _chrome) setState(() => _chrome = false);
    });
  }

  void _toggleChrome() {
    HapticFeedback.selectionClick();
    setState(() => _chrome = !_chrome);
    if (_chrome) _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final key = (sourceId: widget.sourceId, chapterId: widget.chapterId);
    final pages = ref.watch(pagesProvider(key));
    final c = context.koma;
    final top = MediaQuery.paddingOf(context).top;
    final count = pages.value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AsyncView(
            value: pages,
            onRetry: () => ref.invalidate(pagesProvider(key)),
            loading: const _ReaderLoading(),
            builder: (list) => list.isEmpty
                ? Center(
                    child: Text(
                      'El capítulo no tiene páginas',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleChrome,
                    child: !_loaded
                        ? const _ReaderLoading()
                        : ScrollablePositionedList.builder(
                            itemScrollController: _itemScroll,
                            itemPositionsListener: _positions,
                            initialScrollIndex: _startIndex.clamp(
                              0,
                              list.length - 1,
                            ),
                            initialAlignment: _startAlign,
                            physics: const BouncingScrollPhysics(),
                            minCacheExtent: 3000,
                            itemCount: _count = list.length,
                            itemBuilder: (_, i) => _PageImage(
                              sourceId: widget.sourceId,
                              chapterId: widget.chapterId,
                              page: list[i],
                            ),
                          ),
                  ),
          ),
          // Progreso de lectura (línea fina en el borde superior).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, p, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: p,
                  child: Container(height: 3, color: c.accent),
                ),
              ),
            ),
          ),
          // Barra superior de cristal.
          Positioned(
            top: top + 10,
            left: 14,
            right: 14,
            child: IgnorePointer(
              ignoring: !_chrome,
              child: AnimatedSlide(
                offset: _chrome ? Offset.zero : const Offset(0, -1.6),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _chrome ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  child: _TopBar(title: widget.title ?? 'Lector'),
                ),
              ),
            ),
          ),
          // Contador de páginas.
          if (count > 0)
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (_, p, _) {
                  final page = count <= 1 ? 1 : (p * (count - 1)).round() + 1;
                  return AnimatedOpacity(
                    opacity: _chrome ? 1 : 0.55,
                    duration: const Duration(milliseconds: 300),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: Colors.black.withValues(alpha: 0.5),
                          child: Text(
                            '$page / $count',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 20, 6),
          color: Colors.black.withValues(alpha: 0.55),
          child: Row(
            children: [
              Pressable(
                onTap: () => context.pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Preparando capítulo…',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _PageImage extends ConsumerWidget {
  const _PageImage({
    required this.sourceId,
    required this.chapterId,
    required this.page,
  });

  final String sourceId;
  final String chapterId;
  final ReaderPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceId: sourceId, chapterId: chapterId, index: page.index);
    final t = Theme.of(context).textTheme;
    final c = context.koma;
    return ref
        .watch(pageImageProvider(key))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(height: 460, child: Skeleton(radius: 0)),
          ),
          error: (e, _) => SizedBox(
            height: 280,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar la página ${page.index + 1}',
                      style: t.titleSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$e',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 14),
                    Pressable(
                      onTap: () => ref.invalidate(pageImageProvider(key)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Reintentar',
                          style: t.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (bytes) => Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
              opacity: frame == null && !sync ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              child: child,
            ),
            errorBuilder: (_, _, _) => const SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Imagen no válida',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
        );
  }
}
