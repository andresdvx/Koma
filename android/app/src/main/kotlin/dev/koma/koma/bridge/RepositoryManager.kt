package dev.koma.koma.bridge

import android.app.Application
import eu.kanade.tachiyomi.network.NetworkHelper
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Request
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get
import java.io.File
import java.io.IOException

/**
 * Repositorios de extensiones con formato Mihon/Keiyoushi (`index.min.json` + `apk/`).
 * Solo HTTPS. Si el repositorio publica `repo.json` con `signingKeyFingerprint`, el APK
 * descargado debe estar firmado con esa clave; la confianza para ejecutarlo sigue siendo
 * una decisión explícita del usuario.
 */
class RepositoryManager(private val app: Application, private val loader: ExtensionLoader) {

    private val prefs = app.getSharedPreferences("koma_repos", 0)
    private val json = Json { ignoreUnknownKeys = true }
    private val client get() = Injekt.get<NetworkHelper>().client

    fun repositories(): List<String> {
        if (!prefs.contains(KEY)) return listOf(DEFAULT_REPO)
        return prefs.getStringSet(KEY, emptySet())!!.sorted()
    }

    /**
     * Añade un repositorio a partir de lo que pegó el usuario: la carpeta del repositorio,
     * la URL de su `index.min.json`, un enlace `mihon://add-repo?url=…` o la página web / repo
     * de GitHub que lo describe. Cada candidato se valida descargando su índice antes de guardarlo.
     */
    fun add(rawUrl: String): Map<String, Any?> {
        val candidates = candidatesFor(rawUrl)
        val failures = mutableListOf<String>()
        for (base in candidates) {
            try {
                validateIndex(base)
            } catch (t: Throwable) {
                failures += "$base (${t.message ?: t.javaClass.simpleName})"
                continue
            }
            val alreadyPresent = base in repositories()
            save(repositories() + base)
            // `resolved` es la dirección real detectada (puede diferir de lo pegado).
            return mapOf(
                "repositories" to repositories(),
                "resolved" to base,
                "alreadyPresent" to alreadyPresent,
            )
        }
        throw KomaBridgeException(
            "ExtensionIncompatible",
            "No encontré un repositorio de extensiones válido. Probé: ${failures.joinToString("; ")}",
        )
    }

    /** Un repositorio válido publica `index.min.json`: una lista de extensiones con `pkg` y `apk`. */
    private fun validateIndex(base: String) {
        val index = fetchIndex(base)
        val ok = index.isNotEmpty() && index.take(5).all {
            val o = it as? JsonObject
            o != null && "pkg" in o && "apk" in o && "code" in o
        }
        if (!ok) throw IOException("el índice está vacío o no tiene el formato esperado")
    }

    fun remove(base: String): List<String> {
        save(repositories() - base)
        return repositories()
    }

    private fun save(list: List<String>) =
        prefs.edit().putStringSet(KEY, list.toSet()).apply()

    // La lógica de resolución de URLs vive en el companion para poder probarla sin Android.

    /** Catálogo combinado de todos los repositorios, con estado respecto a lo instalado. */
    fun catalog(installedCodes: (String) -> Long?): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val errors = mutableListOf<String>()
        for (repo in repositories()) {
            try {
                for (e in fetchIndex(repo)) {
                    val o = e.jsonObject
                    val pkg = o.str("pkg")
                    val code = o["code"]!!.jsonPrimitive.long
                    val installed = installedCodes(pkg)
                    out += mapOf(
                        "repo" to repo,
                        "id" to pkg,
                        "name" to o.str("name").removePrefix("Tachiyomi: "),
                        "version" to o.str("version"),
                        "versionCode" to code,
                        "language" to o.str("lang"),
                        "nsfw" to ((o["nsfw"]?.jsonPrimitive?.long ?: 0L) == 1L),
                        "status" to when {
                            installed == null -> "available"
                            installed < code -> "update"
                            else -> "installed"
                        },
                    )
                }
            } catch (t: Throwable) {
                errors += "$repo: ${t.message}"
            }
        }
        if (out.isEmpty() && errors.isNotEmpty()) {
            throw KomaBridgeException("NetworkError", errors.joinToString("; "))
        }
        return out
    }

    private fun fetchIndex(repo: String): JsonArray =
        json.parseToJsonElement(getText("$repo/index.min.json")).jsonArray

    private fun fingerprint(repo: String): String? = try {
        json.parseToJsonElement(getText("$repo/repo.json")).jsonObject["meta"]?.jsonObject
            ?.get("signingKeyFingerprint")?.jsonPrimitive?.content
            ?.replace(":", "")?.lowercase()
    } catch (_: Exception) {
        null // repo.json es opcional
    }

    /** Descarga, valida y copia un APK del repositorio. Queda sin confiar. */
    fun install(repo: String, packageName: String): LoadedExtensionInfo {
        if (repo !in repositories()) {
            throw KomaBridgeException("ExtensionNotFound", "Repositorio no registrado")
        }
        val entry = fetchIndex(repo).map { it.jsonObject }.firstOrNull { it.str("pkg") == packageName }
            ?: throw KomaBridgeException("ExtensionNotFound", packageName)
        val apkName = entry.str("apk")
        if (apkName.contains('/') || apkName.contains("..") || !apkName.endsWith(".apk")) {
            throw KomaBridgeException("ExtensionIncompatible", "Nombre de APK no válido")
        }
        val tmp = File(app.cacheDir, "dl_$packageName.apk")
        try {
            download("$repo/apk/$apkName", tmp)
            val info = loader.inspect(tmp)
            if (info.packageName != packageName) {
                throw KomaBridgeException("ExtensionIncompatible", "El APK no corresponde a $packageName")
            }
            fingerprint(repo)?.let {
                if (!info.signatureSha256.equals(it, ignoreCase = true)) {
                    throw KomaBridgeException("ExtensionNotTrusted", "La firma no coincide con la del repositorio")
                }
            }
            return loader.import(tmp)
        } finally {
            tmp.delete()
        }
    }

    private fun getText(url: String): String =
        client.newCall(Request.Builder().url(url).build()).execute().use { r ->
            requireHttps(r)
            if (!r.isSuccessful) throw IOException("HTTP ${r.code}")
            r.body.string()
        }

    /** Una redirección no puede degradar la conexión a http. */
    private fun requireHttps(r: okhttp3.Response) {
        if (r.request.url.scheme != "https") throw IOException("redirección a una URL no https")
    }

    private fun download(url: String, target: File) {
        client.newCall(Request.Builder().url(url).build()).execute().use { r ->
            requireHttps(r)
            if (!r.isSuccessful) throw IOException("HTTP ${r.code}")
            if (r.body.contentLength() > MAX_APK_BYTES) {
                throw KomaBridgeException("ExtensionIncompatible", "APK demasiado grande")
            }
            target.outputStream().use { out ->
                r.body.byteStream().use { input ->
                    val buf = ByteArray(16 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > MAX_APK_BYTES) {
                            throw KomaBridgeException("ExtensionIncompatible", "APK demasiado grande")
                        }
                        out.write(buf, 0, n)
                    }
                }
            }
        }
    }

    private fun JsonObject.str(k: String) = this[k]!!.jsonPrimitive.content

    companion object {
        /** Ramas donde las extensiones del ecosistema Mihon publican el índice, por orden de preferencia. */
        private val INDEX_BRANCHES = listOf("repo", "main")

        /**
         * Devuelve, por orden de preferencia, las carpetas que podrían ser el repositorio.
         * No hace red: [add] valida cada una. Solo HTTPS.
         */
        internal fun candidatesFor(raw: String): List<String> {
            var s = raw.trim()
            // Enlaces de adición: mihon://add-repo?url=https%3A%2F%2F…
            Regex("^[a-z][a-z0-9+.-]*://add-repo\\?(.*)$", RegexOption.IGNORE_CASE).find(s)?.let { m ->
                val param = m.groupValues[1].split('&')
                    .map { it.split('=', limit = 2) }
                    .firstOrNull { it.size == 2 && it[0] == "url" }
                    ?.get(1)
                    ?: throw KomaBridgeException("ExtensionIncompatible", "El enlace add-repo no trae url")
                s = java.net.URLDecoder.decode(param, "UTF-8").trim()
            }

            val base = normalize(s)
            val url = base.toHttpUrlOrNull()
                ?: throw KomaBridgeException("ExtensionIncompatible", "La URL del repositorio debe ser https válida")
            val segments = url.pathSegments.filter { it.isNotEmpty() }

            // Páginas que describen un repositorio: <dueño>.github.io/<repo> o github.com/<dueño>/<repo>.
            val ownerRepo: Pair<String, String>? = when {
                url.host.endsWith(".github.io") && segments.isNotEmpty() ->
                    url.host.removeSuffix(".github.io") to segments[0]
                url.host == "github.com" && segments.size >= 2 -> segments[0] to segments[1]
                else -> null
            }

            val out = linkedSetOf(base)
            if (ownerRepo != null) {
                val (owner, repo) = ownerRepo
                INDEX_BRANCHES.forEach { out += "https://raw.githubusercontent.com/$owner/$repo/$it" }
            }
            return out.toList()
        }

        /** Acepta la URL del índice o la de su carpeta; devuelve la carpeta sin barra final. */
        internal fun normalize(raw: String): String {
            var s = raw.trim().trimEnd('/')
            if (s.endsWith(".json")) s = s.substringBeforeLast('/')
            val url = s.toHttpUrlOrNull()
            if (url == null || url.scheme != "https") {
                throw KomaBridgeException("ExtensionIncompatible", "La URL del repositorio debe ser https válida")
            }
            return s
        }

        private const val KEY = "repos"
        const val DEFAULT_REPO = "https://raw.githubusercontent.com/keiyoushi/extensions/repo"
        private const val MAX_APK_BYTES = 100L * 1024 * 1024
    }
}
