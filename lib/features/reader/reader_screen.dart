import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';

typedef ChapterKey = ({String sourceId, String chapterId});

final pagesProvider =
    FutureProvider.autoDispose.family<List<ReaderPage>, ChapterKey>((ref, k) {
  return ref
      .watch(sourceClientProvider)
      .getPages(sourceId: k.sourceId, chapterId: k.chapterId);
});

/// Lector vertical continuo. No conoce el origen de las páginas: solo URL + cabeceras.
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
  bool _chrome = true;

  @override
  Widget build(BuildContext context) {
    final key = (sourceId: widget.sourceId, chapterId: widget.chapterId);
    final pages = ref.watch(pagesProvider(key));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chrome
          ? AppBar(
              title: Text(widget.title ?? 'Lector'),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            )
          : null,
      body: AsyncView(
        value: pages,
        onRetry: () => ref.invalidate(pagesProvider(key)),
        builder: (list) => list.isEmpty
            ? const Center(
                child: Text('El capítulo no tiene páginas',
                    style: TextStyle(color: Colors.white70)))
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _chrome = !_chrome),
                child: ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _PageImage(
                    sourceId: widget.sourceId,
                    chapterId: widget.chapterId,
                    page: list[i],
                  ),
                ),
              ),
      ),
    );
  }
}

typedef PageKey = ({String sourceId, String chapterId, int index});

/// Bytes de cada página, descargados por el motor. Se conservan mientras dure la app
/// para no volver a descargar al hacer scroll (pendiente: limitar memoria).
final pageImageProvider =
    FutureProvider.family<Uint8List, PageKey>((ref, k) {
  return ref.watch(sourceClientProvider).getPageImage(
        sourceId: k.sourceId,
        chapterId: k.chapterId,
        pageIndex: k.index,
      );
});

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
    return ref.watch(pageImageProvider(key)).when(
          loading: () => const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 260,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'No se pudo cargar la página ${page.index + 1}\n$e',
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(pageImageProvider(key)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
          data: (bytes) => Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 200,
              child: Center(
                child: Text('Imagen no válida',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        );
  }
}
