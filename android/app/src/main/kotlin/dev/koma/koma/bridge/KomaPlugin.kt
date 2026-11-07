package dev.koma.koma.bridge

import android.app.Application
import eu.kanade.tachiyomi.network.NetworkHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton
import uy.kohesive.injekt.api.fullType
import java.io.File

/** Puente Flutter <-> motor Android. Devuelve solo estructuras serializables. */
class KomaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var channel: MethodChannel? = null
    private lateinit var loader: ExtensionLoader
    private lateinit var registry: ExtensionRegistry
    private lateinit var adapter: SourceAdapter
    private lateinit var repos: RepositoryManager
    private lateinit var localSource: LocalSource

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val app = binding.applicationContext as Application
        registerHostServices(app)
        loader = ExtensionLoader(app)
        localSource = LocalSource(app)
        registry = ExtensionRegistry(loader, localSource)
        adapter = SourceAdapter(registry)
        repos = RepositoryManager(app, loader)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        scope.cancel()
    }

    /** Servicios que las extensiones obtienen vía Injekt. */
    private fun registerHostServices(app: Application) {
        Injekt.addSingleton(fullType<Application>(), app)
        Injekt.addSingleton(fullType<NetworkHelper>(), NetworkHelper(app))
        Injekt.addSingleton(fullType<Json>(), Json { ignoreUnknownKeys = true })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val value: Any? = withTimeout(TIMEOUT_MS) { dispatch(call) }
                result.success(value)
            } catch (t: Throwable) {
                val e = if (t is TimeoutCancellationException) {
                    KomaBridgeException("NetworkError", "Tiempo de espera agotado")
                } else {
                    t.toBridgeException()
                }
                result.error(e.code, e.message, null)
            }
        }
    }

    private suspend fun dispatch(call: MethodCall): Any? {
        fun arg(name: String) = call.argument<String>(name) ?: throw IllegalArgumentException("Falta $name")
        return when (call.method) {
            "getExtensions" -> {
                registry.refresh()
                registry.extensions()
            }
            "importExtension" -> {
                registry.add(loader.import(File(arg("path"))))
                registry.extensions()
            }
            "listDeviceExtensions" -> loader.listDeviceExtensions()
            "importDeviceExtension" -> {
                registry.add(loader.importFromDevice(arg("id")))
                registry.extensions()
            }
            "trustExtension" -> {
                registry.trust(arg("id"))
                registry.extensions()
            }
            "importLocal" -> localSource.import(File(arg("path")))
            "deleteLocal" -> {
                localSource.delete(arg("id"))
                null
            }
            "getRepositories" -> repos.repositories()
            "addRepository" -> repos.add(arg("url"))
            "removeRepository" -> repos.remove(arg("url"))
            "getCatalog" -> {
                registry.refresh()
                repos.catalog(registry::versionCode)
            }
            "installExtension" -> {
                registry.add(repos.install(arg("repo"), arg("id")))
                registry.extensions()
            }
            "uninstallExtension" -> {
                registry.remove(arg("id"))
                registry.extensions()
            }
            "getSources" -> registry.sourceList()
            "searchManga" -> adapter.search(
                arg("sourceId"),
                call.argument<String>("query") ?: "",
                call.argument<Int>("page") ?: 1,
            )
            "getManga" -> adapter.manga(arg("sourceId"), arg("mangaId"))
            "getChapters" -> adapter.chapters(arg("sourceId"), arg("mangaId"))
            "getPages" -> adapter.pages(arg("sourceId"), arg("chapterId"))
            "getPageImage" -> adapter.pageImage(
                arg("sourceId"),
                arg("chapterId"),
                call.argument<Int>("pageIndex") ?: 0,
            )
            else -> throw KomaBridgeException("UnknownError", "Método desconocido: ${call.method}")
        }
    }

    companion object {
        const val CHANNEL = "dev.koma/source"
        private const val TIMEOUT_MS = 60_000L
    }
}
