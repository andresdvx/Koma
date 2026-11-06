/// DTOs serializables del contrato Koma. IDs siempre como String.
class ExtensionInfo {
  const ExtensionInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.language,
    this.trusted = false,
  });

  final String id;
  final String name;
  final String version;
  final String language;
  final bool trusted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'language': language,
        'trusted': trusted,
      };

  factory ExtensionInfo.fromJson(Map<String, dynamic> j) => ExtensionInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        version: j['version'] as String,
        language: j['language'] as String,
        trusted: j['trusted'] as bool? ?? false,
      );
}

class MangaSourceInfo {
  const MangaSourceInfo({
    required this.id,
    required this.extensionId,
    required this.name,
    required this.language,
  });

  final String id;
  final String extensionId;
  final String name;
  final String language;

  Map<String, dynamic> toJson() => {
        'id': id,
        'extensionId': extensionId,
        'name': name,
        'language': language,
      };

  factory MangaSourceInfo.fromJson(Map<String, dynamic> j) => MangaSourceInfo(
        id: j['id'] as String,
        extensionId: j['extensionId'] as String,
        name: j['name'] as String,
        language: j['language'] as String,
      );
}

/// Resumen de manga en listados. Identidad: (sourceId, id).
class MangaSummary {
  const MangaSummary({
    required this.sourceId,
    required this.id,
    required this.title,
    this.coverUrl,
  });

  final String sourceId;
  final String id;
  final String title;
  final String? coverUrl;

  Map<String, dynamic> toJson() =>
      {'sourceId': sourceId, 'id': id, 'title': title, 'coverUrl': coverUrl};

  factory MangaSummary.fromJson(Map<String, dynamic> j) => MangaSummary(
        sourceId: j['sourceId'] as String,
        id: j['id'] as String,
        title: j['title'] as String,
        coverUrl: j['coverUrl'] as String?,
      );
}

class MangaPageResult {
  const MangaPageResult({required this.items, required this.hasNextPage});

  final List<MangaSummary> items;
  final bool hasNextPage;

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'hasNextPage': hasNextPage,
      };

  factory MangaPageResult.fromJson(Map<String, dynamic> j) => MangaPageResult(
        items: (j['items'] as List)
            .map((e) =>
                MangaSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasNextPage: j['hasNextPage'] as bool,
      );
}

class MangaDetail {
  const MangaDetail({
    required this.sourceId,
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.description,
    this.genres = const [],
    this.status,
  });

  final String sourceId;
  final String id;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? description;
  final List<String> genres;
  final String? status;

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'id': id,
        'title': title,
        'coverUrl': coverUrl,
        'author': author,
        'description': description,
        'genres': genres,
        'status': status,
      };

  factory MangaDetail.fromJson(Map<String, dynamic> j) => MangaDetail(
        sourceId: j['sourceId'] as String,
        id: j['id'] as String,
        title: j['title'] as String,
        coverUrl: j['coverUrl'] as String?,
        author: j['author'] as String?,
        description: j['description'] as String?,
        genres: (j['genres'] as List? ?? const []).cast<String>(),
        status: j['status'] as String?,
      );
}

class Chapter {
  const Chapter({
    required this.id,
    required this.mangaId,
    required this.name,
    this.number,
    this.uploadedAt,
  });

  final String id;
  final String mangaId;
  final String name;
  final double? number;
  final DateTime? uploadedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mangaId': mangaId,
        'name': name,
        'number': number,
        'uploadedAt': uploadedAt?.toIso8601String(),
      };

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        mangaId: j['mangaId'] as String,
        name: j['name'] as String,
        number: (j['number'] as num?)?.toDouble(),
        uploadedAt: j['uploadedAt'] == null
            ? null
            : DateTime.parse(j['uploadedAt'] as String),
      );
}

class ReaderPage {
  const ReaderPage({
    required this.index,
    required this.imageUrl,
    this.headers = const {},
  });

  final int index;
  final String imageUrl;

  /// Cabeceras resueltas por el motor; no deben incluir credenciales sensibles.
  final Map<String, String> headers;

  Map<String, dynamic> toJson() =>
      {'index': index, 'imageUrl': imageUrl, 'headers': headers};

  factory ReaderPage.fromJson(Map<String, dynamic> j) => ReaderPage(
        index: j['index'] as int,
        imageUrl: j['imageUrl'] as String,
        headers: Map<String, String>.from(j['headers'] as Map? ?? const {}),
      );
}
