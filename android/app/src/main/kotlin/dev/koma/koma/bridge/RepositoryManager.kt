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

    fun add(rawUrl: String): List<String> {
        val base = normalize(rawUrl)
        save(repositories() + base)
        return repositories()
    }

    fun remove(base: String): List<String> {
        save(repositories() - base)
        return repositories()
    }

    private fun save(list: List<String>) =
        prefs.edit().putStringSet(KEY, list.toSet()).apply()

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
            if (!r.isSuccessful) throw IOException("HTTP ${r.code} en $url")
            r.body.string()
        }

    private fun download(url: String, target: File) {
        client.newCall(Request.Builder().url(url).build()).execute().use { r ->
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
        private const val KEY = "repos"
        const val DEFAULT_REPO = "https://raw.githubusercontent.com/keiyoushi/extensions/repo"
        private const val MAX_APK_BYTES = 100L * 1024 * 1024
    }
}
