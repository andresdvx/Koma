import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../../core/source_providers.dart';
import '../../shared/widgets/async_view.dart';

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
  int _page = 0;
  bool _hasNext = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0; // descarta respuestas de búsquedas anteriores

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
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
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
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

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: [
          IconButton(
            tooltip: 'Extensiones',
            icon: const Icon(Icons.extension),
            onPressed: () async {
              await context.push('/extensions');
              ref.invalidate(sourcesProvider);
            },
          ),
        ],
      ),
      body: AsyncView(
        value: sources,
        onRetry: () => ref.invalidate(sourcesProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No hay fuentes disponibles'));
          }
          if (_sourceId == null || !list.any((s) => s.id == _sourceId)) {
            final first = list.first.id;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => mounted ? _reset(first) : null);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Flexible(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: list.any((s) => s.id == _sourceId)
                            ? _sourceId
                            : list.first.id,
                        items: [
                          for (final s in list)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text('${s.name} (${s.language})',
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => v == null ? null : _reset(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Buscar manga',
                          prefixIcon: Icon(Icons.search),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          _query = v.trim();
                          if (_sourceId != null) _reset(_sourceId!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _results()),
            ],
          );
        },
      ),
    );
  }

  Widget _results() {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return _errorBox();
      return const Center(child: Text('Sin resultados'));
    }
    // Si el contenido aún no llena la pantalla no habrá scroll que dispare la carga.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _hasNext &&
          !_loading &&
          _error == null &&
          _scroll.hasClients &&
          _scroll.position.extentAfter < 600) {
        _loadMore();
      }
    });
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + 1,
      itemBuilder: (context, i) {
        if (i == _items.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) return _errorBox();
          return const SizedBox(height: 24);
        }
        final m = _items[i];
        return ListTile(
          leading: _Cover(url: m.coverUrl),
          title: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => context.push(
              '/manga/${Uri.encodeComponent(m.sourceId)}/${Uri.encodeComponent(m.id)}'),
        );
      },
    );
  }

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error', textAlign: TextAlign.center),
            TextButton(onPressed: _loadMore, child: const Text('Reintentar')),
          ],
        ),
      );
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const w = 48.0, h = 68.0;
    final placeholder = Container(
      width: w,
      height: h,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book, size: 20),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, p) => p == null ? child : placeholder,
      ),
    );
  }
}
