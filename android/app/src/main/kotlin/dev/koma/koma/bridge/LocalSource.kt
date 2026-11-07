package dev.koma.koma.bridge

import android.app.Application
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.SMangaUpdate
import java.io.File
import java.util.zip.ZipFile

/**
 * Fuente integrada para archivos CBZ/ZIP importados. Cada archivo es un manga con un único
 * capítulo (el propio archivo). El lector no distingue su origen: recibe páginas por índice.
 */
class LocalSource(app: Application) : Source {

    private val dir = File(app.filesDir, "local").apply { mkdirs() }

    override val id: Long = 0x4C4F43414CL // "LOCAL"
    override val name: String = "Local"
    override val lang: String = "all"
    override val supportsLatest: Boolean = false

    // --- Importación -----------------------------------------------------------------------

    /** Copia un CBZ/ZIP al almacenamiento privado tras validar que contiene imágenes. */
    fun import(source: File): String {
        val base = source.name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        if (!base.lowercase().let { it.endsWith(".cbz") || it.endsWith(".zip") }) {
            throw KomaBridgeException("ExtensionIncompatible", "Solo se admiten archivos .cbz o .zip")
        }
        val entries = try {
            ZipFile(source).use { imageEntries(it) }
        } catch (e: java.util.zip.ZipException) {
            throw KomaBridgeException("ExtensionIncompatible", "El archivo no es un ZIP válido")
        }
        if (entries.isEmpty()) {
            throw KomaBridgeException("ContentUnavailable", "El archivo no contiene imágenes")
        }
        var target = File(dir, base)
        var n = 1
        while (target.exists()) {
            target = File(dir, "${base.substringBeforeLast('.')} (${n++}).${base.substringAfterLast('.')}")
        }
        source.copyTo(target)
        return target.name
    }

    fun delete(fileName: String) {
        val f = resolve(fileName)
        if (!f.delete()) throw KomaBridgeException("ContentUnavailable", "No se pudo eliminar $fileName")
    }

    // --- Source ----------------------------------------------------------------------------

    private fun files(): List<File> =
        dir.listFiles { f -> f.isFile && f.extension.lowercase() in setOf("cbz", "zip") }
            .orEmpty().sortedBy { it.name.lowercase() }

    private fun manga(f: File) = SManga.create().apply {
        url = f.name
        title = f.nameWithoutExtension
        status = SManga.COMPLETED
    }

    override suspend fun getPopularManga(page: Int): MangasPage =
        MangasPage(files().map(::manga), hasNextPage = false)

    override suspend fun getLatestUpdates(page: Int): MangasPage =
        throw UnsupportedOperationException()

    override suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage =
        MangasPage(
            files().filter { it.nameWithoutExtension.contains(query, ignoreCase = true) }.map(::manga),
            hasNextPage = false,
        )

    override suspend fun getMangaUpdate(
        manga: SManga,
        chapters: List<SChapter>,
        fetchDetails: Boolean,
        fetchChapters: Boolean,
    ): SMangaUpdate {
        val f = resolve(manga.url)
        val details = manga(f)
        val list = if (fetchChapters) {
            listOf(
                SChapter.create().apply {
                    url = f.name
                    name = f.nameWithoutExtension
                    date_upload = f.lastModified()
                },
            )
        } else {
            chapters
        }
        return SMangaUpdate(if (fetchDetails) details else manga, list)
    }

    override suspend fun getPageList(chapter: SChapter): List<Page> {
        val f = resolve(chapter.url)
        val n = ZipFile(f).use { imageEntries(it).size }
        return (0 until n).map { Page(it, url = chapter.url) }
    }

    /** Bytes de una página del archivo. */
    fun readPage(fileName: String, index: Int): ByteArray {
        val f = resolve(fileName)
        ZipFile(f).use { zip ->
            val entry = imageEntries(zip).getOrNull(index)
                ?: throw KomaBridgeException("ContentUnavailable", "Página $index no existe")
            if (entry.size > MAX_PAGE_BYTES) {
                throw KomaBridgeException("ContentUnavailable", "Imagen demasiado grande")
            }
            return zip.getInputStream(entry).use { it.readBytes() }
        }
    }

    // --- Utilidades ------------------------------------------------------------------------

    /** Impide salir del directorio local con ids manipulados. */
    private fun resolve(fileName: String): File {
        val f = File(dir, fileName)
        if (f.canonicalFile.parentFile != dir.canonicalFile || !f.isFile) {
            throw KomaBridgeException("ContentUnavailable", "Archivo local no encontrado")
        }
        return f
    }

    private fun imageEntries(zip: ZipFile) = zip.entries().asSequence()
        .filter { !it.isDirectory && !it.name.startsWith("__MACOSX") }
        .filter { e -> e.name.substringAfterLast('.').lowercase() in IMAGE_EXT }
        .sortedWith { a, b -> naturalCompare(a.name, b.name) }
        .toList()

    companion object {
        const val SOURCE_ID = "local"
        const val EXTENSION_ID = "koma.local"
        private val IMAGE_EXT = setOf("jpg", "jpeg", "png", "webp", "gif", "avif")
        private const val MAX_PAGE_BYTES = 60L * 1024 * 1024

        /** Orden natural: "page2" antes que "page10". */
        internal fun naturalCompare(a: String, b: String): Int {
            val ra = Regex("\\d+|\\D+").findAll(a.lowercase()).map { it.value }.toList()
            val rb = Regex("\\d+|\\D+").findAll(b.lowercase()).map { it.value }.toList()
            for (i in 0 until minOf(ra.size, rb.size)) {
                val x = ra[i]
                val y = rb[i]
                val c = if (x[0].isDigit() && y[0].isDigit()) {
                    val d = x.trimStart('0').length.compareTo(y.trimStart('0').length)
                    if (d != 0) d else x.trimStart('0').compareTo(y.trimStart('0'))
                } else {
                    x.compareTo(y)
                }
                if (c != 0) return c
            }
            return ra.size.compareTo(rb.size)
        }
    }
}
