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
  });
}
