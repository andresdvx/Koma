package dev.koma.koma.bridge

import android.app.Application
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import dalvik.system.PathClassLoader
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import java.io.File
import java.security.MessageDigest

/** Metadatos de una extensión importada (APK sin modificar, copiado a almacenamiento privado). */
data class LoadedExtensionInfo(
    val packageName: String,
    val name: String,
    val versionName: String,
    val language: String,
    val signatureSha256: String,
    val classNames: List<String>,
    val apkFile: File,
)

class ExtensionLoader(private val app: Application) {

    private val dir = File(app.filesDir, "extensions").apply { mkdirs() }
    private val prefs = app.getSharedPreferences("koma_trust", 0)

    // --- Confianza -----------------------------------------------------------------------

    fun isTrusted(info: LoadedExtensionInfo): Boolean =
        prefs.getStringSet(TRUST_KEY, emptySet())!!.contains("${info.packageName}:${info.signatureSha256}")

    fun trust(info: LoadedExtensionInfo) {
        val set = prefs.getStringSet(TRUST_KEY, emptySet())!!.toMutableSet()
        set += "${info.packageName}:${info.signatureSha256}"
        prefs.edit().putStringSet(TRUST_KEY, set).apply()
    }

    // --- Inspección e importación ---------------------------------------------------------

    /** Lee y valida un APK sin ejecutarlo. */
    fun inspect(apk: File): LoadedExtensionInfo {
        @Suppress("DEPRECATION")
        val sigFlag = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
        else PackageManager.GET_SIGNATURES
        val flags = PackageManager.GET_CONFIGURATIONS or PackageManager.GET_META_DATA or sigFlag
        val pkg = app.packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: throw KomaBridgeException("ExtensionIncompatible", "No es un APK válido")
        if (pkg.reqFeatures.orEmpty().none { it.name == EXTENSION_FEATURE }) {
            throw KomaBridgeException("ExtensionIncompatible", "No declara la feature $EXTENSION_FEATURE")
        }
        val appInfo = pkg.applicationInfo
            ?: throw KomaBridgeException("ExtensionIncompatible", "APK sin application")
        val classes = (appInfo.metaData?.getString(METADATA_CLASS) ?: "")
            .split(";").map { it.trim() }.filter { it.isNotEmpty() }
            .map { if (it.startsWith(".")) pkg.packageName + it else it }
        if (classes.isEmpty()) {
            throw KomaBridgeException("ExtensionIncompatible", "Falta $METADATA_CLASS")
        }
        appInfo.sourceDir = apk.absolutePath
        appInfo.publicSourceDir = apk.absolutePath
        val label = appInfo.loadLabel(app.packageManager).toString().removePrefix("Tachiyomi: ")
        return LoadedExtensionInfo(
            packageName = pkg.packageName,
            name = label,
            versionName = pkg.versionName ?: "?",
            language = pkg.packageName.substringAfter("eu.kanade.tachiyomi.extension.").substringBefore('.'),
            signatureSha256 = signatureHash(pkg)
                ?: throw KomaBridgeException("ExtensionNotTrusted", "APK sin firma"),
            classNames = classes,
            apkFile = apk,
        )
    }

    /** Copia el APK al almacenamiento privado verificando continuidad de firma. */
    fun import(source: File): LoadedExtensionInfo {
        val incoming = inspect(source)
        val target = File(dir, "${incoming.packageName}.apk")
        if (target.exists()) {
            val current = inspect(target)
            if (current.signatureSha256 != incoming.signatureSha256) {
                throw KomaBridgeException(
                    "ExtensionNotTrusted",
                    "La firma de ${incoming.packageName} cambió respecto a la instalada",
                )
            }
            target.setWritable(true)
            target.delete()
        }
        source.copyTo(target, overwrite = true)
        target.setReadOnly() // Android 14+: los dex cargados dinámicamente deben ser de solo lectura
        return inspect(target)
    }

    /** Extensiones Mihon/Tachiyomi instaladas en el teléfono (aún no importadas en Koma). */
    fun listDeviceExtensions(): List<Map<String, Any?>> {
        @Suppress("DEPRECATION")
        val all = app.packageManager.getInstalledPackages(PackageManager.GET_CONFIGURATIONS)
        return all.filter { p -> p.reqFeatures.orEmpty().any { it.name == EXTENSION_FEATURE } }
            .map { p ->
                mapOf(
                    "id" to p.packageName,
                    "name" to (p.applicationInfo?.loadLabel(app.packageManager)?.toString() ?: p.packageName)
                        .removePrefix("Tachiyomi: "),
                    "version" to (p.versionName ?: "?"),
                    "language" to p.packageName.substringAfter("eu.kanade.tachiyomi.extension.").substringBefore('.'),
                    "trusted" to false,
                )
            }
    }

    /** Importa (copia sin modificar) el APK de una extensión instalada en el dispositivo. */
    fun importFromDevice(packageName: String): LoadedExtensionInfo {
        val info = try {
            app.packageManager.getApplicationInfo(packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            throw KomaBridgeException("ExtensionNotFound", packageName)
        }
        return import(File(info.sourceDir))
    }

    fun installed(): List<LoadedExtensionInfo> =
        dir.listFiles { f -> f.extension == "apk" }.orEmpty()
            .mapNotNull { runCatching { inspect(it) }.getOrNull() }

    // --- Carga ----------------------------------------------------------------------------

    /** Instancia las fuentes de una extensión. Solo debe llamarse tras confiar en ella. */
    fun load(info: LoadedExtensionInfo): List<Source> {
        if (!isTrusted(info)) throw KomaBridgeException("ExtensionNotTrusted", info.packageName)
        val loader = PathClassLoader(info.apkFile.absolutePath, app.classLoader)
        return info.classNames.flatMap { name ->
            when (val instance = Class.forName(name, false, loader).getDeclaredConstructor().newInstance()) {
                is Source -> listOf(instance)
                is SourceFactory -> instance.createSources()
                else -> throw KomaBridgeException("ExtensionIncompatible", "Clase inesperada: $name")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun signatureHash(pkg: PackageInfo): String? {
        val sigs = if (Build.VERSION.SDK_INT >= 28) {
            pkg.signingInfo?.let {
                if (it.hasMultipleSigners()) it.apkContentsSigners else it.signingCertificateHistory
            }
        } else {
            pkg.signatures
        }
        val first = sigs?.firstOrNull() ?: return null
        return MessageDigest.getInstance("SHA-256").digest(first.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    companion object {
        const val EXTENSION_FEATURE = "tachiyomi.extension"
        const val METADATA_CLASS = "tachiyomi.extension.class"
        private const val TRUST_KEY = "trusted"
    }
}
