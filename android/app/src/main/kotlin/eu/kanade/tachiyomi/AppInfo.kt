package eu.kanade.tachiyomi

import dev.koma.koma.BuildConfig

/** Información del host expuesta a las extensiones (extensions-lib 1.3). */
@Suppress("Unused")
object AppInfo {
    /** Código de versión de Koma. */
    fun getVersionCode(): Int = BuildConfig.VERSION_CODE

    /** Nombre de versión de Koma. */
    fun getVersionName(): String = BuildConfig.VERSION_NAME
}
