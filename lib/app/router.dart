import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koma_source_api/koma_source_api.dart';

import '../features/browse/browse_screen.dart';
import '../features/extensions/extensions_screen.dart';
import '../features/library/library_screen.dart';
import '../features/manga_details/manga_details_screen.dart';
import '../features/reader/reader_screen.dart';
import '../shared/widgets/dock.dart';

/// Cambio de pestaña: fundido suave.
CustomTransitionPage<void> _fade(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, anim, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: c,
      ),
    );

/// Pantallas de detalle: sube desde abajo con fundido (las portadas vuelan con Hero).
CustomTransitionPage<void> _rise(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (_, anim, sec, c) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curve),
            child: c,
          ),
        );
      },
    );

/// Un router por instancia de la app (los tests no comparten estado de navegación).
GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    routes: [
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, s) => _fade(s, const BrowseScreen()),
          ),
          GoRoute(
            path: '/library',
            pageBuilder: (_, s) => _fade(s, const LibraryScreen()),
          ),
          GoRoute(
            path: '/extensions',
            pageBuilder: (_, s) => _fade(s, const ExtensionsScreen()),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/manga/:sourceId/:mangaId',
        pageBuilder: (_, s) => _rise(
          s,
          MangaDetailsScreen(
            sourceId: s.pathParameters['sourceId']!,
            mangaId: s.pathParameters['mangaId']!,
            summary: s.extra is MangaSummary ? s.extra! as MangaSummary : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/reader/:sourceId/:chapterId',
        pageBuilder: (_, s) => _rise(
          s,
          ReaderScreen(
            sourceId: s.pathParameters['sourceId']!,
            chapterId: s.pathParameters['chapterId']!,
            title: s.uri.queryParameters['title'],
          ),
        ),
      ),
    ],
  );
}

/// Contenedor de las pestañas principales con el dock flotante.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _items = [
    DockItem(Icons.auto_stories_rounded, 'Explorar'),
    DockItem(Icons.favorite_rounded, 'Biblioteca'),
    DockItem(Icons.extension_rounded, 'Extensiones'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/extensions')
        ? 2
        : location.startsWith('/library')
            ? 1
            : 0;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Dock(
                items: _items,
                index: index,
                onSelect: (i) => context.go(const ['/', '/library', '/extensions'][i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
