import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/platform/android_source_client.dart';
import 'package:koma_source_api/koma_source_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.koma/source');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('traduce respuestas del bridge a DTOs', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getExtensions':
          return [
            {'id': 'e', 'name': 'E', 'version': '1', 'language': 'es', 'trusted': true}
          ];
        case 'searchManga':
          return {
            'items': [
              {'sourceId': '9', 'id': '/m/1', 'title': 'T', 'coverUrl': null}
            ],
            'hasNextPage': true,
          };
        case 'getPages':
          return [
            {'index': 0, 'imageUrl': 'https://x/0.jpg', 'headers': {'Referer': 'x'}}
          ];
      }
      return null;
    });
    final c = AndroidSourceClient();
    expect((await c.getExtensions()).single.trusted, isTrue);
    final r = await c.searchManga(sourceId: '9', query: '', page: 1);
    expect(r.items.single.id, '/m/1');
    expect(r.hasNextPage, isTrue);
    final p = await c.getPages(sourceId: '9', chapterId: 'c');
    expect(p.single.headers['Referer'], 'x');
  });

  test('errores nativos se convierten en KomaError tipado', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'ExtensionNotTrusted', message: 'x');
    });
    expect(
      AndroidSourceClient().getSources(),
      throwsA(isA<ExtensionNotTrusted>()),
    );
  });

  test('sin plugin nativo lanza RuntimeUnavailable', () {
    expect(AndroidSourceClient().getSources(), throwsA(isA<RuntimeUnavailable>()));
  });
}
