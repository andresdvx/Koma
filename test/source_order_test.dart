import 'package:flutter_test/flutter_test.dart';
import 'package:koma/core/source_order.dart';
import 'package:koma_source_api/koma_source_api.dart';

MangaSourceInfo _s(String lang, [String name = 'MangaDex']) =>
    MangaSourceInfo(id: '$name$lang', extensionId: 'e', name: name, language: lang);

void main() {
  test('idioma del dispositivo primero, luego inglés, luego el resto', () {
    final sorted = sortSourcesByLanguage(
      [_s('af'), _s('en'), _s('fr'), _s('es-la'), _s('es')],
      'es',
    ).map((s) => s.language).toList();
    expect(sorted, ['es', 'es-la', 'en', 'af', 'fr']);
  });

  test('no modifica la lista original', () {
    final original = [_s('fr'), _s('es')];
    sortSourcesByLanguage(original, 'es');
    expect(original.first.language, 'fr');
  });
}
