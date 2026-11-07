import 'package:flutter/services.dart';
import 'package:koma_source_api/koma_source_api.dart';

enum CatalogStatus { available, installed, update }

/// Extensión publicada en un repositorio.
class CatalogEntry {
  const CatalogEntry({
    required this.repo,
    required this.id,
    required this.name,
    required this.version,
    required this.language,
    required this.nsfw,
    required this.status,
  });

  final String repo;
  final String id;
  final String name;
  final String version;
  final String language;
  final bool nsfw;
  final CatalogStatus status;

  factory CatalogEntry.fromJson(Map<String, dynamic> j) => CatalogEntry(
        repo: j['repo'] as String,
        id: j['id'] as String,
        name: j['name'] as String,
        version: j['version'] as String,
        language: j['language'] as String,
        nsfw: j['nsfw'] as bool? ?? false,
        status: CatalogStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => CatalogStatus.available,
        ),
      );
}

/// Implementación de [SourceClient] sobre el bridge Kotlin (MethodChannel).
class AndroidSourceClient implements SourceClient {
  AndroidSourceClient([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('dev.koma/source');

  final MethodChannel _channel;

  Future<T> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      final r = await _channel.invokeMethod<Object?>(method, args);
      return r as T;
    } on PlatformException catch (e) {
      throw KomaError.fromCode(e.code, e.message ?? '');
    } on MissingPluginException {
      throw const RuntimeUnavailable('Motor Android no disponible');
    }
  }

  static Map<String, dynamic> _map(Object? o) =>
      Map<String, dynamic>.from(o! as Map);

  Future<List<Map<String, dynamic>>> _list(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final r = await _call<List<Object?>?>(method, args);
    return (r ?? const []).map(_map).toList();
  }

  @override
  Future<List<ExtensionInfo>> getExtensions() async =>
      (await _list('getExtensions')).map(ExtensionInfo.fromJson).toList();

  /// Importa un APK de extensión (sin modificarlo). Queda sin confiar.
  Future<List<ExtensionInfo>> importExtension(String apkPath) async =>
      (await _list('importExtension', {'path': apkPath}))
          .map(ExtensionInfo.fromJson)
          .toList();

  /// Extensiones Mihon/Tachiyomi instaladas en el teléfono.
  Future<List<ExtensionInfo>> listDeviceExtensions() async =>
      (await _list('listDeviceExtensions')).map(ExtensionInfo.fromJson).toList();

  /// Copia (sin modificar) el APK de una extensión instalada. Queda sin confiar.
  Future<List<ExtensionInfo>> importDeviceExtension(String packageName) async =>
      (await _list('importDeviceExtension', {'id': packageName}))
          .map(ExtensionInfo.fromJson)
          .toList();

  /// Confianza explícita del usuario antes de ejecutar código de terceros.
  Future<List<ExtensionInfo>> trustExtension(String extensionId) async =>
      (await _list('trustExtension', {'id': extensionId}))
          .map(ExtensionInfo.fromJson)
          .toList();

  // --- Repositorios y catálogo (específico de Android) -------------------------------

  Future<List<String>> getRepositories() async =>
      ((await _call<List<Object?>?>('getRepositories')) ?? const [])
          .cast<String>();

  Future<List<String>> addRepository(String url) async =>
      ((await _call<List<Object?>?>('addRepository', {'url': url})) ??
              const [])
          .cast<String>();

  Future<List<String>> removeRepository(String url) async =>
      ((await _call<List<Object?>?>('removeRepository', {'url': url})) ??
              const [])
          .cast<String>();

  Future<List<CatalogEntry>> getCatalog() async =>
      (await _list('getCatalog')).map(CatalogEntry.fromJson).toList();

  /// Descarga e instala (sin confiar) o actualiza una extensión de un repositorio.
  Future<List<ExtensionInfo>> installExtension(String repo, String id) async =>
      (await _list('installExtension', {'repo': repo, 'id': id}))
          .map(ExtensionInfo.fromJson)
          .toList();

  Future<List<ExtensionInfo>> uninstallExtension(String id) async =>
      (await _list('uninstallExtension', {'id': id}))
          .map(ExtensionInfo.fromJson)
          .toList();

  @override
  Future<List<MangaSourceInfo>> getSources() async =>
      (await _list('getSources')).map(MangaSourceInfo.fromJson).toList();

  @override
  Future<MangaPageResult> searchManga({
    required String sourceId,
    required String query,
    required int page,
  }) async =>
      MangaPageResult.fromJson(_map(await _call<Object?>('searchManga', {
        'sourceId': sourceId,
        'query': query,
        'page': page,
      })));

  @override
  Future<MangaDetail> getManga({
    required String sourceId,
    required String mangaId,
  }) async =>
      MangaDetail.fromJson(_map(await _call<Object?>(
          'getManga', {'sourceId': sourceId, 'mangaId': mangaId})));

  @override
  Future<List<Chapter>> getChapters({
    required String sourceId,
    required String mangaId,
  }) async =>
      (await _list('getChapters', {'sourceId': sourceId, 'mangaId': mangaId}))
          .map(Chapter.fromJson)
          .toList();

  @override
  Future<List<ReaderPage>> getPages({
    required String sourceId,
    required String chapterId,
  }) async =>
      (await _list('getPages', {'sourceId': sourceId, 'chapterId': chapterId}))
          .map(ReaderPage.fromJson)
          .toList();

  @override
  Future<Uint8List> getPageImage({
    required String sourceId,
    required String chapterId,
    required int pageIndex,
  }) =>
      _call<Uint8List>('getPageImage', {
        'sourceId': sourceId,
        'chapterId': chapterId,
        'pageIndex': pageIndex,
      });
}
