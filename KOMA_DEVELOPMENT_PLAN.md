# Koma Reader — Plan de desarrollo técnico

> **Objetivo:** desarrollar un lector de manga para Android y Windows con Flutter, capaz de utilizar extensiones existentes de Tachiyomi/Mihon y abrir un capítulo lo antes posible. También se incorporará lectura local CBZ/ZIP.

## 1. Estrategia y prioridades

Construiremos primero un **vertical slice**: cargar una extensión APK existente → identificar fuentes → buscar manga → consultar capítulos → recuperar páginas → leer un capítulo.

| Prioridad | Funcionalidad |
|---|---|
| P0 | Cargar y ejecutar una extensión existente en Android |
| P0 | Buscar manga y obtener capítulos |
| P0 | Leer páginas reales |
| P1 | Motor de extensiones Windows |
| P1 | Gestor de extensiones y repositorios |
| P1 | Biblioteca e historial |
| P2 | Archivos CBZ/ZIP, descargas y offline |
| P2 | Sincronización |

**Decisión:** validar Android primero, ya que las extensiones son APK diseñados para ese entorno. Windows permanece en el diseño, pero no bloqueará el primer capítulo legible.

## 2. Stack tecnológico

| Componente | Tecnología |
|---|---|
| UI multiplataforma | Flutter / Dart |
| Estado | Riverpod |
| Navegación | GoRouter |
| Persistencia posterior | Drift + SQLite |
| Motor Android | Kotlin, API de fuentes Mihon/Tachiyomi |
| Flutter ↔ Kotlin | MethodChannel inicialmente |
| Motor Windows | JVM + capa de compatibilidad, sujeto a prueba |
| Networking Android | OkHttp / dependencias requeridas por el host |
| Pruebas | flutter_test, JUnit y pruebas de integración |
| Organización | Monorepo Flutter + Gradle |

No se requiere backend para el MVP.

## 3. Arquitectura

```text
                   Koma UI (Flutter)
             Explorar / Detalles / Lector
                           |
                    Koma Source API
                  DTO + SourceClient
                           |
                 Adaptadores de plataforma
                  /                    \
        Android Adapter           Windows Adapter
       Kotlin + APK/Dex          JVM + runtime/IPC
                  \                    /
            Extensiones Tachiyomi / Mihon
```

**Nota:** una JVM no ejecuta automáticamente un APK Android. Windows requiere resolver compatibilidad con bibliotecas, clases Android y recursos usados por cada extensión. El motor se validará antes de adoptarlo definitivamente.

### 3.1 Estructura del repositorio

```text
koma/
├── android/
│   └── app/src/main/kotlin/.../bridge/
│       ├── KomaPlugin.kt
│       ├── ExtensionLoader.kt
│       ├── ExtensionRegistry.kt
│       └── SourceAdapter.kt
├── windows/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── errors/
│   │   └── platform/
│   ├── features/
│   │   ├── extensions/
│   │   ├── browse/
│   │   ├── manga_details/
│   │   ├── reader/
│   │   ├── library/
│   │   └── local_import/
│   └── shared/
│       ├── models/
│       └── widgets/
├── packages/
│   └── koma_source_api/lib/
│       ├── source_client.dart
│       ├── manga.dart
│       ├── chapter.dart
│       └── manga_page.dart
├── native/
│   └── windows_runtime/
├── test/
├── integration_test/
├── docs/
│   ├── architecture.md
│   ├── contracts.md
│   ├── decisions/
│   └── roadmap.md
└── pubspec.yaml
```

Separar `data`, `domain` y `presentation` por funcionalidad cuando exista una necesidad real; evitar capas vacías.

## 4. Contratos

La UI no conoce objetos internos de Mihon. Todo pasa por un contrato multiplataforma:

```dart
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
}
```

Los tipos `ExtensionInfo`, `MangaSourceInfo`, `MangaPageResult`, `MangaDetail`, `Chapter` y `ReaderPage` se definirán como DTO serializables en `koma_source_api`.

### 4.1 Reglas de contratos

- IDs de fuentes como cadenas para evitar pérdida de precisión al serializar.
- Identidad de manga: combinación de `sourceId` y `mangaId`.
- Una extensión puede exponer varias fuentes e idiomas.
- Búsqueda paginada, con indicador de más resultados.
- Páginas ordenadas y resueltas por el motor; no exponer credenciales en Flutter.
- Tiempo límite y cancelación o mecanismo equivalente para operaciones largas.
- Errores nativos transformados en errores tipados.
- Implementaciones Android y Windows sujetas a las mismas pruebas de contrato.

### 4.2 Errores tipados

```text
KomaError
├── ExtensionNotFound
├── ExtensionNotTrusted
├── ExtensionIncompatible
├── SourceNotFound
├── NetworkError
├── AuthenticationRequired
├── RateLimited
├── ContentUnavailable
├── RuntimeUnavailable
└── UnknownError
```

## 5. Reglas del proyecto

### Arquitectura

1. Flutter nunca carga APK directamente.
2. Las pantallas usan `SourceClient`, no clases nativas de Mihon.
3. El bridge devuelve exclusivamente DTO serializables.
4. El lector desconoce el origen de las páginas.
5. Android y Windows implementan el mismo contrato.
6. No introducir abstracciones sin un caso de uso real.

### Seguridad

1. No ejecutar extensiones desconocidas automáticamente.
2. Validar metadatos, versión y firmas de los paquetes.
3. Solicitar confianza explícita al usuario antes de ejecutar código de terceros.
4. Verificar continuidad de firmas durante las actualizaciones.
5. Mantener el runtime de Windows limitado a localhost/IPC y sin privilegios elevados; localhost por sí solo no garantiza aislamiento.
6. No registrar tokens, contraseñas ni cookies sensibles.
7. Tratar las extensiones como código potencialmente no confiable, incluso si están firmadas.
8. Respetar derechos de autor y condiciones de las fuentes; probar inicialmente con contenido autorizado.

### Calidad

1. Cada fase termina con un ejecutable o prueba reproducible.
2. Las funcionalidades necesitan criterios de aceptación y pruebas.
3. Registrar decisiones arquitectónicas en `docs/decisions/`.
4. Posponer sincronización, recomendaciones y personalización hasta leer un capítulo real.

## 6. Fases del desarrollo

| Fase | Estimación orientativa | Objetivo | Entregable |
|---|---|---|---|
| 0 — Preparación | 0,5–1 día | Flutter, Android, contratos, navegación mínima | App ejecutable en Android |
| 1 — Carga de extensión | 2–5 días o más | Cargar APK de prueba, validar firma, identificar fuentes y dependencias host | Extensión y fuentes visibles |
| 2 — Explorar manga | 1–3 días | `getSources`, `searchManga`, `getManga`, `getChapters` | Búsqueda y capítulos reales |
| 3 — Primer capítulo | 1–3 días | `getPages`, imágenes y lector vertical | Capítulo legible en Android |
| 4 — Windows | 3–8+ días | Evaluar runtime, bridge de escritorio, misma extensión | Capítulo legible en Windows |
| 5 — Biblioteca | 2–4 días | SQLite, favoritos, historial, progreso | Biblioteca persistente |
| 6 — Gestor de extensiones | 3–6 días | Repositorios, índices, instalación y actualizaciones | Instalar extensiones desde Koma |
| 7 — Local/offline | 3–5 días | Importar CBZ/ZIP, descargas permitidas | Lector híbrido |

> Las duraciones no son compromisos: incompatibilidades con APIs, dependencias Android o extensiones concretas pueden ampliar mucho el trabajo, especialmente en Windows.

## 7. Primer sprint

### 7.1 Crear proyecto

```powershell
flutter doctor -v
flutter create --platforms=android,windows --org dev.koma koma
cd koma
flutter pub add flutter_riverpod go_router
flutter pub add path collection
flutter run
```

### 7.2 Git

```bash
git init
git add .
git commit -m "chore: initialize Koma Flutter project"
git switch -c develop
git switch -c feature/source-contracts
```

Usar ramas `feature/*` e integrar cambios probados en `develop`. Mantener `main` para versiones estables.

### 7.3 Contrato y cliente falso

- [ ] Crear `packages/koma_source_api`.
- [ ] Definir DTO serializables y `SourceClient`.
- [ ] Implementar `FakeSourceClient` con contenido de prueba.
- [ ] Crear pantalla de fuentes y resultados usando el cliente falso.
- [ ] Implementar `AndroidSourceClient` mediante MethodChannel.
- [ ] Probar que ambos clientes respetan los mismos contratos.

### 7.4 Prueba de compatibilidad

- [ ] Elegir una extensión existente sencilla y una fuente de contenido autorizado.
- [ ] Revisar interfaces y dependencias de la versión de extensión.
- [ ] Revisar el cargador y gestor de extensiones de Mihon.
- [ ] Cargar el APK original sin modificarlo.
- [ ] Identificar y mostrar al menos una fuente.
- [ ] Obtener mangas, capítulos y páginas.
- [ ] Comparar resultados con un host Mihon compatible.

## 8. Criterios de aceptación del primer MVP

- [ ] APK existente reconocido y cargado sin modificarlo.
- [ ] Se identifica al menos una fuente.
- [ ] Se consultan mangas reales de una fuente de prueba autorizada.
- [ ] Se muestran detalles y capítulos.
- [ ] Se recuperan todas las páginas de un capítulo.
- [ ] Se renderizan las imágenes en Flutter.
- [ ] Errores y fallos de red no cierran la aplicación.

**Definición de terminado:** el usuario puede abrir Koma en Android, usar una extensión Mihon/Tachiyomi existente, elegir un manga y leer un capítulo completo.

## 9. Roadmap de versiones

| Versión | Hito |
|---|---|
| `v0.0.1` | Proyecto y contratos |
| `v0.0.2` | Primera extensión cargada |
| `v0.0.3` | Exploración de mangas |
| `v0.1.0` | Primer capítulo en Android |
| `v0.2.0` | Lectura con extensiones en Windows |
| `v0.3.0` | Biblioteca persistente |
| `v0.4.0` | Gestor de extensiones |
| `v0.5.0` | Archivos locales y descargas |
| `v1.0.0` | Versión estable |

## 10. Referencias técnicas

- [Mihon](https://github.com/mihonapp/mihon) — arquitectura del host, cargador y gestión de extensiones.
- [TachiyomiX](https://github.com/mihonapp/tachiyomix) — contratos y dependencias de extensiones.
- [Keiyoushi extensions-source](https://github.com/keiyoushi/extensions-source) — ejemplos de extensiones Kotlin.
- [Keiyoushi extensions](https://github.com/keiyoushi/extensions) — distribución comunitaria de extensiones.
- [M-Extension-Server](https://github.com/kodjodevf/M-Extension-Server) — candidato a runtime de escritorio, pendiente de validar.
- [Flutter](https://docs.flutter.dev/) — documentación oficial.

**Siguiente acción:** iniciar la fase 0 y realizar cuanto antes una prueba de carga de una extensión existente en Android. La viabilidad de esa prueba determina el resto del proyecto.
