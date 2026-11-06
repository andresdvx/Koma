package dev.koma.koma.bridge

import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.online.HttpSource
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Traduce la API de Source de Mihon a mapas serializables (DTO del contrato de Koma). */
class SourceAdapter(private val registry: ExtensionRegistry) {

    suspend fun search(sourceId: String, query: String, page: Int): Map<String, Any?> {
        val s = registry.source(sourceId)
        val result = if (query.isBlank()) {
            s.getPopularManga(page)
        } else {
            s.getSearchManga(page, query, s.getFilterList())
        }
        return mapOf(
            "items" to result.mangas.map { summary(sourceId, it) },
            "hasNextPage" to result.hasNextPage,
        )
    }

    suspend fun manga(sourceId: String, mangaId: String): Map<String, Any?> {
        val s = registry.source(sourceId)
        val m = s.getMangaUpdate(stub(mangaId), emptyList(), fetchDetails = true, fetchChapters = false).manga
        return mapOf(
            "sourceId" to sourceId,
            "id" to mangaId,
            "title" to m.title.ifEmpty { mangaId },
            "coverUrl" to m.thumbnail_url,
            "author" to m.author,
            "description" to m.description,
            "genres" to (m.genre?.split(",")?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()),
            "status" to when (m.status) {
                SManga.ONGOING -> "En curso"
                SManga.COMPLETED -> "Finalizado"
                SManga.LICENSED -> "Licenciado"
                else -> null
            },
        )
    }

    suspend fun chapters(sourceId: String, mangaId: String): List<Map<String, Any?>> {
        val s = registry.source(sourceId)
        return s.getMangaUpdate(stub(mangaId), emptyList(), fetchDetails = false, fetchChapters = true)
            .chapters.map { c ->
                mapOf(
                    "id" to c.url,
                    "mangaId" to mangaId,
                    "name" to c.name,
                    "number" to c.chapter_number.takeIf { it >= 0 }?.toDouble(),
                    "uploadedAt" to c.date_upload.takeIf { it > 0 }?.let(::iso),
                )
            }
    }

    suspend fun pages(sourceId: String, chapterId: String): List<Map<String, Any?>> {
        val s = registry.source(sourceId)
        val chapter = SChapter.create().apply { url = chapterId; name = chapterId }
        val headers = (s as? HttpSource)?.headers?.toMultimap()
            ?.mapValues { it.value.joinToString(",") } ?: emptyMap()
        return s.getPageList(chapter).sortedBy { it.index }.map { p ->
            if (p.imageUrl.isNullOrEmpty() && s is HttpSource) p.imageUrl = s.getImageUrl(p)
            mapOf("index" to p.index, "imageUrl" to (p.imageUrl ?: ""), "headers" to headers)
        }
    }

    private fun stub(mangaId: String) = SManga.create().apply { url = mangaId; title = "" }

    private fun summary(sourceId: String, m: SManga) =
        mapOf("sourceId" to sourceId, "id" to m.url, "title" to m.title, "coverUrl" to m.thumbnail_url)

    private fun iso(ms: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }
            .format(Date(ms))
}
