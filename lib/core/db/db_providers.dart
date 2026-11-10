import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final libraryProvider = StreamProvider<List<LibraryEntry>>(
    (ref) => ref.watch(databaseProvider).watchLibrary());

final recentReadsProvider = StreamProvider<List<ReadingHistoryData>>(
    (ref) => ref.watch(databaseProvider).watchRecent());

typedef LibKey = ({String sourceId, String mangaId});

final inLibraryProvider = StreamProvider.family<bool, LibKey>((ref, k) =>
    ref.watch(databaseProvider).watchInLibrary(k.sourceId, k.mangaId));

final mangaProgressProvider =
    StreamProvider.family<Map<String, ReadingHistoryData>, LibKey>((ref, k) =>
        ref.watch(databaseProvider).watchMangaProgress(k.sourceId, k.mangaId));
