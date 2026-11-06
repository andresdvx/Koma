import 'package:go_router/go_router.dart';

import '../features/browse/browse_screen.dart';
import '../features/extensions/extensions_screen.dart';
import '../features/manga_details/manga_details_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const BrowseScreen()),
    GoRoute(path: '/extensions', builder: (_, _) => const ExtensionsScreen()),
    GoRoute(
      path: '/manga/:sourceId/:mangaId',
      builder: (_, state) => MangaDetailsScreen(
        sourceId: state.pathParameters['sourceId']!,
        mangaId: state.pathParameters['mangaId']!,
      ),
    ),
  ],
);
