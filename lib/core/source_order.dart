import 'package:koma_source_api/koma_source_api.dart';

/// Ordena las fuentes: idioma del dispositivo primero, luego inglés, luego el resto
/// (por idioma y nombre). Los códigos regionales ("es-la") cuentan como su idioma base.
List<MangaSourceInfo> sortSourcesByLanguage(
  List<MangaSourceInfo> sources,
  String deviceLanguage,
) {
  String base(String lang) => lang.toLowerCase().split(RegExp('[-_]')).first;
  int rank(MangaSourceInfo s) {
    final l = base(s.language);
    if (l == deviceLanguage.toLowerCase()) return 0;
    if (l == 'en') return 1;
    return 2;
  }

  final sorted = [...sources];
  sorted.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final l = a.language.compareTo(b.language);
    return l != 0 ? l : a.name.compareTo(b.name);
  });
  return sorted;
}
