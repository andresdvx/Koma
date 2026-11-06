import 'models.dart';

/// Contrato único entre la UI y los motores (Android, Windows, fake).
/// Todas las implementaciones deben lanzar subtipos de `KomaError`.
abstract interface class SourceClient {
  Future<List<ExtensionInfo>> getExtensions();
  Future<List<MangaSourceInfo>> getSources();

  Future<MangaPageResult> searchManga({
    required String sourceId,
    required String query,
    required int page,
  });

  Future<MangaDetail> getManga({
    required String sourceId,
    required String mangaId,
  });

  Future<List<Chapter>> getChapters({
    required String sourceId,
    required String mangaId,
  });

  Future<List<ReaderPage>> getPages({
    required String sourceId,
    required String chapterId,
  });
}
