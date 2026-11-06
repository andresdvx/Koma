import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koma_source_api/koma_source_api.dart';

import 'platform/android_source_client.dart';

/// Cliente activo: motor real en Android; cliente falso en el resto
/// (Windows usará su propio motor en la fase 4).
final sourceClientProvider = Provider<SourceClient>((ref) {
  if (!kIsWeb && Platform.isAndroid) return AndroidSourceClient();
  return FakeSourceClient();
});

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
