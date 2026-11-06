package dev.koma.koma.bridge

import eu.kanade.tachiyomi.source.Source

/** Mantiene las extensiones cargadas y sus fuentes, indexadas por id (cadena). */
class ExtensionRegistry(private val loader: ExtensionLoader) {

    private val infos = linkedMapOf<String, LoadedExtensionInfo>()
    private val sources = linkedMapOf<String, Pair<String, Source>>() // sourceId -> (extId, source)

    @Synchronized
    fun refresh() {
        infos.clear()
        sources.clear()
        loader.installed().forEach { infos[it.packageName] = it }
        infos.values.filter(loader::isTrusted).forEach { loadInto(it) }
    }

    @Synchronized
    fun add(info: LoadedExtensionInfo) {
        infos[info.packageName] = info
        sources.entries.removeAll { it.value.first == info.packageName }
        if (loader.isTrusted(info)) loadInto(info)
    }

    private fun loadInto(info: LoadedExtensionInfo) {
        loader.load(info).forEach { sources[it.id.toString()] = info.packageName to it }
    }

    @Synchronized
    fun trust(extensionId: String) {
        val info = infos[extensionId] ?: throw KomaBridgeException("ExtensionNotFound", extensionId)
        loader.trust(info)
        add(info)
    }

    @Synchronized
    fun extensions(): List<Map<String, Any?>> = infos.values.map {
        mapOf(
            "id" to it.packageName,
            "name" to it.name,
            "version" to it.versionName,
            "language" to it.language,
            "trusted" to loader.isTrusted(it),
        )
    }

    @Synchronized
    fun sourceList(): List<Map<String, Any?>> = sources.map { (id, p) ->
        mapOf("id" to id, "extensionId" to p.first, "name" to p.second.name, "language" to p.second.lang)
    }

    @Synchronized
    fun source(id: String): Source =
        sources[id]?.second ?: throw KomaBridgeException("SourceNotFound", id)
}
