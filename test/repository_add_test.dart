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

  const raw = 'https://raw.githubusercontent.com/keiyoushi/extensions/repo';

  test('un repositorio nuevo se informa como añadido y con su URL real', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'addRepository');
      expect(call.arguments['url'], 'https://keiyoushi.github.io/extensions/');
      return {
        'repositories': [raw],
        'resolved': raw,
        'alreadyPresent': false,
      };
    });
    final r = await AndroidSourceClient()
        .addRepository('https://keiyoushi.github.io/extensions/');
    expect(r.resolved, raw);
    expect(r.alreadyPresent, isFalse);
    expect(r.message, 'Repositorio añadido: $raw');
  });

  test('si ya estaba, el mensaje lo dice (no hay éxito silencioso)', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => {
          'repositories': [raw],
          'resolved': raw,
          'alreadyPresent': true,
        });
    final r = await AndroidSourceClient().addRepository(raw);
    expect(r.message, contains('Ya estaba en tu lista'));
    expect(r.message, contains(raw));
  });

  test('un repositorio inválido propaga un error tipado con el motivo', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'ExtensionIncompatible',
        message: 'No encontré un repositorio de extensiones válido. Probé: x',
      );
    });
    expect(
      AndroidSourceClient().addRepository('https://example.com/'),
      throwsA(isA<ExtensionIncompatible>()
          .having((e) => e.message, 'message', contains('No encontré'))),
    );
  });
}
