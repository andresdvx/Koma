import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

/// Cliente activo. Por ahora falso; se reemplazará por AndroidSourceClient.
final sourceClientProvider =
    Provider<SourceClient>((ref) => FakeSourceClient());

final sourcesProvider = FutureProvider<List<MangaSourceInfo>>(
  (ref) => ref.watch(sourceClientProvider).getSources(),
);

typedef SearchArgs = ({String sourceId, String query});

final searchProvider =
    FutureProvider.family<MangaPageResult, SearchArgs>((ref, args) {
  return ref
      .watch(sourceClientProvider)
      .searchManga(sourceId: args.sourceId, query: args.query, page: 1);
});

typedef MangaKey = ({String sourceId, String mangaId});

final mangaDetailProvider =
    FutureProvider.family<MangaDetail, MangaKey>((ref, k) {
  return ref
      .watch(sourceClientProvider)
      .getManga(sourceId: k.sourceId, mangaId: k.mangaId);
});

final chaptersProvider =
    FutureProvider.family<List<Chapter>, MangaKey>((ref, k) {
  return ref
      .watch(sourceClientProvider)
      .getChapters(sourceId: k.sourceId, mangaId: k.mangaId);
});
