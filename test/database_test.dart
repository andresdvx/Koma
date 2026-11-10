import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('biblioteca: añadir, no duplicar y quitar', () async {
    await db.addToLibrary(sourceId: 's', mangaId: 'm', title: 'Uno');
    await db.addToLibrary(sourceId: 's', mangaId: 'm', title: 'Uno (editado)');
    final list = await db.watchLibrary().first;
    expect(list, hasLength(1));
    expect(list.single.title, 'Uno (editado)');
    expect(await db.watchInLibrary('s', 'm').first, isTrue);

    await db.removeFromLibrary('s', 'm');
    expect(await db.watchInLibrary('s', 'm').first, isFalse);
  });

  test('progreso: se conserva al reabrir y marca leído al 95 %', () async {
    Future<void> open(String ch) => db.touchChapter(
          sourceId: 's',
          mangaId: 'm',
          mangaTitle: 'Uno',
          chapterId: ch,
          chapterName: 'Cap $ch',
        );
    await open('c1');
    await db.saveProgress('s', 'c1', 0.4);
    await open('c1'); // reabrir no debe perder el avance
    expect(await db.progressOf('s', 'c1'), closeTo(0.4, 1e-9));

    await db.saveProgress('s', 'c1', 0.97);
    final p = await db.watchMangaProgress('s', 'm').first;
    expect(p['c1']!.finished, isTrue);
  });

  test('posición exacta: página y desplazamiento se guardan y leen', () async {
    await db.touchChapter(
        sourceId: 's', mangaId: 'm', mangaTitle: 'Uno', chapterId: 'c1', chapterName: 'Cap 1');
    await db.saveProgress('s', 'c1', 0.5, pageIndex: 7, pageAlign: -0.35);
    final h = (await db.historyOf('s', 'c1'))!;
    expect(h.pageIndex, 7);
    expect(h.pageAlign, closeTo(-0.35, 1e-9));
  });

  test('recientes: una entrada por manga, la última leída', () async {
    await db.touchChapter(
        sourceId: 's', mangaId: 'm', mangaTitle: 'Uno', chapterId: 'c1', chapterName: 'Cap 1');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.touchChapter(
        sourceId: 's', mangaId: 'm', mangaTitle: 'Uno', chapterId: 'c2', chapterName: 'Cap 2');
    await db.touchChapter(
        sourceId: 's', mangaId: 'x', mangaTitle: 'Otro', chapterId: 'd1', chapterName: 'Cap 1');

    final recent = await db.watchRecent().first;
    expect(recent, hasLength(2));
    expect(recent.firstWhere((h) => h.mangaId == 'm').chapterId, 'c2');
  });
}
