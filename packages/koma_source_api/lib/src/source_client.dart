import 'dart:typed_data';

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

  /// Bytes de la imagen de una página. El motor resuelve la URL final, cabeceras,
  /// cookies y descifrado; la UI nunca descarga imágenes de la fuente por su cuenta.
  Future<Uint8List> getPageImage({
    required String sourceId,
    required String chapterId,
    required int pageIndex,
  });
}
