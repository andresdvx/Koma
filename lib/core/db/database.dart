import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Mangas guardados en la biblioteca. Identidad: (sourceId, mangaId).
class LibraryEntries extends Table {
  TextColumn get sourceId => text()();
  TextColumn get mangaId => text()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sourceId, mangaId};
}

/// Historial y progreso: una fila por capítulo abierto.
class ReadingHistory extends Table {
  TextColumn get sourceId => text()();
  TextColumn get chapterId => text()();
  TextColumn get mangaId => text()();
  TextColumn get mangaTitle => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get chapterName => text()();

  /// Fracción leída del capítulo (0..1).
  RealColumn get progress => real().withDefault(const Constant(0))();
  BoolColumn get finished => boolean().withDefault(const Constant(false))();

  /// Posición exacta: página visible en el borde superior y su desplazamiento
  /// (alineación del borde de la página, ≤ 0 si está parcialmente fuera).
  IntColumn get pageIndex => integer().withDefault(const Constant(0))();
  RealColumn get pageAlign => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sourceId, chapterId};
}

@DriftDatabase(tables: [LibraryEntries, ReadingHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'koma'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(readingHistory, readingHistory.pageIndex);
            await m.addColumn(readingHistory, readingHistory.pageAlign);
          }
        },
      );

  // --- Biblioteca ---------------------------------------------------------------------

  Stream<List<LibraryEntry>> watchLibrary() => (select(libraryEntries)
        ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
      .watch();

  Stream<bool> watchInLibrary(String sourceId, String mangaId) =>
      (select(libraryEntries)
            ..where((t) => t.sourceId.equals(sourceId) & t.mangaId.equals(mangaId)))
          .watchSingleOrNull()
          .map((e) => e != null);

  Future<void> addToLibrary({
    required String sourceId,
    required String mangaId,
    required String title,
    String? coverUrl,
  }) =>
      into(libraryEntries).insertOnConflictUpdate(LibraryEntriesCompanion.insert(
        sourceId: sourceId,
        mangaId: mangaId,
        title: title,
        coverUrl: Value(coverUrl),
        addedAt: DateTime.now(),
      ));

  Future<void> removeFromLibrary(String sourceId, String mangaId) =>
      (delete(libraryEntries)
            ..where((t) => t.sourceId.equals(sourceId) & t.mangaId.equals(mangaId)))
          .go();

  // --- Historial y progreso -------------------------------------------------------------

  /// Registra la apertura de un capítulo sin perder el progreso previo.
  Future<void> touchChapter({
    required String sourceId,
    required String mangaId,
    required String mangaTitle,
    String? coverUrl,
    required String chapterId,
    required String chapterName,
  }) async {
    final existing = await (select(readingHistory)
          ..where((t) => t.sourceId.equals(sourceId) & t.chapterId.equals(chapterId)))
        .getSingleOrNull();
    await into(readingHistory).insertOnConflictUpdate(
      ReadingHistoryCompanion.insert(
        sourceId: sourceId,
        chapterId: chapterId,
        mangaId: mangaId,
        mangaTitle: mangaTitle,
        coverUrl: Value(coverUrl),
        chapterName: chapterName,
        progress: Value(existing?.progress ?? 0),
        finished: Value(existing?.finished ?? false),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Guarda el avance; llegar al 95 % marca el capítulo como leído.
  Future<void> saveProgress(
    String sourceId,
    String chapterId,
    double progress, {
    int pageIndex = 0,
    double pageAlign = 0,
  }) =>
      (update(readingHistory)
            ..where((t) => t.sourceId.equals(sourceId) & t.chapterId.equals(chapterId)))
          .write(ReadingHistoryCompanion(
        progress: Value(progress.clamp(0.0, 1.0)),
        pageIndex: Value(pageIndex),
        pageAlign: Value(pageAlign),
        finished: progress >= 0.95 ? const Value(true) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));

  Future<double> progressOf(String sourceId, String chapterId) async =>
      (await historyOf(sourceId, chapterId))?.progress ?? 0;

  Future<ReadingHistoryData?> historyOf(String sourceId, String chapterId) =>
      (select(readingHistory)
            ..where((t) => t.sourceId.equals(sourceId) & t.chapterId.equals(chapterId)))
          .getSingleOrNull();

  /// Última lectura de cada manga, la más reciente primero.
  Stream<List<ReadingHistoryData>> watchRecent({int limit = 50}) =>
      (select(readingHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch()
          .map((rows) {
        final seen = <(String, String)>{};
        return [
          for (final r in rows)
            if (seen.add((r.sourceId, r.mangaId))) r,
        ].take(limit).toList();
      });

  /// Progreso por capítulo de un manga (para marcar leídos en el detalle).
  Stream<Map<String, ReadingHistoryData>> watchMangaProgress(
    String sourceId,
    String mangaId,
  ) =>
      (select(readingHistory)
            ..where((t) => t.sourceId.equals(sourceId) & t.mangaId.equals(mangaId)))
          .watch()
          .map((rows) => {for (final r in rows) r.chapterId: r});

  Future<void> clearHistory() => delete(readingHistory).go();
}
