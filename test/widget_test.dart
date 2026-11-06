import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koma/app/app.dart';

void main() {
  testWidgets('explorar muestra resultados y abre detalles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KomaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Manga de prueba 1'), findsOneWidget);

    await tester.tap(find.text('Manga de prueba 1'));
    await tester.pumpAndSettle();

    expect(find.text('Capítulo 1'), findsOneWidget);

    await tester.tap(find.text('Capítulo 1'));
    await tester.pumpAndSettle();

    // Lector abierto con el título del capítulo; las imágenes de red fallan en tests
    // y deben degradarse a un mensaje con reintento, sin romper la app.
    expect(find.text('Capítulo 1'), findsOneWidget);
    expect(find.textContaining('No se pudo cargar la página 1'), findsOneWidget);
  });
}
