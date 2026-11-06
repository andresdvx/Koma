import 'package:koma_source_api/koma_source_api.dart';
import 'package:test/test.dart';

/// Suite de contrato reutilizable: cada implementación de SourceClient
/// (Fake, Android, Windows) debe pasarla con una fuente válida.
void sourceClientContract(
  String name,
  SourceClient Function() create, {
  required String sourceId,
}) {
  group('SourceClient contract: $name', () {
    late SourceClient client;
    setUp(() => client = create());

    test('expone extensiones y fuentes', () async {
      expect(await client.getExtensions(), isNotEmpty);
      final sources = await client.getSources();
      expect(sources.map((s) => s.id), contains(sourceId));
    });

    test('búsqueda paginada con hasNextPage', () async {
      var page = 1;
      var r = await client.searchManga(sourceId: sourceId, query: '', page: 1);
      expect(r.items, isNotEmpty);
      while (r.hasNextPage) {
        r = await client.searchManga(
            sourceId: sourceId, query: '', page: ++page);
        expect(r.items, isNotEmpty);
      }
      expect(page, greaterThan(1));
    });

    test('detalle, capítulos y páginas ordenadas', () async {
      final item =
          (await client.searchManga(sourceId: sourceId, query: '', page: 1))
              .items
              .first;
      final detail =
          await client.getManga(sourceId: sourceId, mangaId: item.id);
      expect(detail.id, item.id);
      final chapters =
          await client.getChapters(sourceId: sourceId, mangaId: item.id);
      expect(chapters, isNotEmpty);
      final pages = await client.getPages(
          sourceId: sourceId, chapterId: chapters.first.id);
      expect(pages.map((p) => p.index),
          orderedEquals([for (var i = 0; i < pages.length; i++) i]));
      final bytes = await client.getPageImage(
          sourceId: sourceId, chapterId: chapters.first.id, pageIndex: 0);
      expect(bytes, isNotEmpty);
    });

    test('fuente inexistente lanza SourceNotFound', () {
      expect(
        client.searchManga(sourceId: 'nope', query: '', page: 1),
        throwsA(isA<SourceNotFound>()),
      );
    });

    test('contenido inexistente lanza ContentUnavailable', () {
      expect(
        client.getManga(sourceId: sourceId, mangaId: 'zzz'),
        throwsA(isA<ContentUnavailable>()),
      );
    });

    test('DTOs sobreviven ida y vuelta JSON', () async {
      final r =
          await client.searchManga(sourceId: sourceId, query: '', page: 1);
      final back = MangaPageResult.fromJson(r.toJson());
      expect(back.items.length, r.items.length);
      expect(back.hasNextPage, r.hasNextPage);
    });
  });
}
