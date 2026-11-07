import 'dart:ui' show Size;

import 'package:flutter/material.dart' show Icons, Image;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:koma/app/app.dart';
import 'package:koma/core/db/database.dart';
import 'package:koma/core/db/db_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(WidgetTester tester) async {
  // Tamaño de teléfono (360x800 lógicos): la UI está pensada para él.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
  addTearDown(db.close);
  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const KomaApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el listado carga todas las páginas de resultados', (tester) async {
    await _open(tester);

    // El cliente falso pagina de 3 en 3 (7 mangas): deben aparecer todos.
    expect(find.text('Manga de prueba 7', skipOffstage: false), findsOneWidget);
  });

  testWidgets('el dock cambia entre Explorar y Extensiones', (tester) async {
    await _open(tester);
    expect(find.text('Explorar'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.extension_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Extensiones'), findsWidgets);
    expect(find.text('Extensión falsa'), findsOneWidget);
  });

  testWidgets('favorito en detalles aparece en la biblioteca', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Manga de prueba 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Guardados (1)'), findsOneWidget);
    expect(find.text('Manga de prueba 1'), findsWidgets);
  });

  testWidgets('explorar → detalles → lector con páginas del motor', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Manga de prueba 1'));
    await tester.pumpAndSettle();

    // Detalle: título, botón de empezar y lista de capítulos.
    expect(find.text('Empezar a leer'), findsOneWidget);
    expect(find.text('Capítulo 3'), findsOneWidget);

    await tester.tap(find.text('Capítulo 3'));
    await tester.pumpAndSettle();

    // Lector abierto: las 5 páginas del capítulo falso se descargan vía el motor.
    expect(find.byType(Image, skipOffstage: false), findsNWidgets(5));
  });
}
