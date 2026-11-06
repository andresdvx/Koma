import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'models.dart';
import 'source_client.dart';

/// Cliente con datos de prueba (sin red) para desarrollar UI y contratos.
class FakeSourceClient implements SourceClient {
  FakeSourceClient({this.pageSize = 3});

  final int pageSize;

  static const _source = MangaSourceInfo(
    id: '1001',
    extensionId: 'fake.ext',
    name: 'Fuente de prueba',
    language: 'es',
  );

  static final _titles = [
    for (var i = 1; i <= 7; i++) 'Manga de prueba $i',
  ];

  void _checkSource(String sourceId) {
    if (sourceId != _source.id) throw SourceNotFound('Fuente $sourceId');
  }

  @override
  Future<List<ExtensionInfo>> getExtensions() async => const [
        ExtensionInfo(
          id: 'fake.ext',
          name: 'Extensión falsa',
          version: '0.0.1',
          language: 'es',
          trusted: true,
        ),
      ];

  @override
  Future<List<MangaSourceInfo>> getSources() async => const [_source];

  @override
  Future<MangaPageResult> searchManga({
    required String sourceId,
    required String query,
    required int page,
  }) async {
    _checkSource(sourceId);
    final matches = <int>[
      for (var i = 0; i < _titles.length; i++)
        if (_titles[i].toLowerCase().contains(query.toLowerCase())) i,
    ];
    final start = (page - 1) * pageSize;
    if (page < 1 || start >= matches.length) {
      return const MangaPageResult(items: [], hasNextPage: false);
    }
    final slice = matches.skip(start).take(pageSize);
    return MangaPageResult(
      items: [
        for (final i in slice)
          MangaSummary(sourceId: sourceId, id: 'm${i + 1}', title: _titles[i]),
      ],
      hasNextPage: start + pageSize < matches.length,
    );
  }

  @override
  Future<MangaDetail> getManga({
    required String sourceId,
    required String mangaId,
  }) async {
    _checkSource(sourceId);
    final n = int.tryParse(mangaId.replaceFirst('m', ''));
    if (n == null || n < 1 || n > _titles.length) {
      throw const ContentUnavailable('Manga no existe');
    }
    return MangaDetail(
      sourceId: sourceId,
      id: mangaId,
      title: _titles[n - 1],
      author: 'Autor de prueba',
      description: 'Descripción de prueba.',
      genres: const ['Acción', 'Aventura'],
      status: 'En curso',
    );
  }

  @override
  Future<List<Chapter>> getChapters({
    required String sourceId,
    required String mangaId,
  }) async {
    await getManga(sourceId: sourceId, mangaId: mangaId);
    return [
      for (var i = 3; i >= 1; i--)
        Chapter(
          id: '$mangaId-c$i',
          mangaId: mangaId,
          name: 'Capítulo $i',
          number: i.toDouble(),
        ),
    ];
  }

  // PNG 1x1 válido, para pruebas sin red.
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  Future<Uint8List> getPageImage({
    required String sourceId,
    required String chapterId,
    required int pageIndex,
  }) async {
    final pages = await getPages(sourceId: sourceId, chapterId: chapterId);
    if (pageIndex < 0 || pageIndex >= pages.length) {
      throw const ContentUnavailable('Página no existe');
    }
    return _png;
  }

  @override
  Future<List<ReaderPage>> getPages({
    required String sourceId,
    required String chapterId,
  }) async {
    _checkSource(sourceId);
    if (!RegExp(r'^m\d+-c\d+$').hasMatch(chapterId)) {
      throw const ContentUnavailable('Capítulo no existe');
    }
    return [
      for (var i = 0; i < 5; i++)
        ReaderPage(
          index: i,
          imageUrl: 'https://picsum.photos/seed/$chapterId-$i/800/1200',
        ),
    ];
  }
}
