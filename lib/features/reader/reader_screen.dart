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
                  itemBuilder: (_, i) => _PageImage(page: list[i]),
                ),
              ),
      ),
    );
  }
}

class _PageImage extends StatefulWidget {
  const _PageImage({required this.page});
  final ReaderPage page;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    if (p.imageUrl.isEmpty) return _error('Página ${p.index + 1} sin imagen');
    return Image.network(
      p.imageUrl,
      key: ValueKey('${p.index}-$_attempt'),
      headers: p.headers,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 400,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes == null
                  ? null
                  : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => _error('No se pudo cargar la página ${p.index + 1}'),
    );
  }

  Widget _error(String msg) => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(msg, style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () => setState(() => _attempt++),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}
