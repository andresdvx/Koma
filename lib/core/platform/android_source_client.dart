import 'package:flutter/services.dart';
import 'package:koma_source_api/koma_source_api.dart';

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
}
