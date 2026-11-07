package dev.koma.koma.bridge

import eu.kanade.tachiyomi.network.HttpException
import java.io.IOException

/** Error tipado del bridge; `code` coincide con los subtipos de KomaError en Dart. */
class KomaBridgeException(val code: String, message: String) : Exception(message)

fun Throwable.toBridgeException(): KomaBridgeException = when (this) {
    is KomaBridgeException -> this
    is HttpException -> when (code) {
        401 -> KomaBridgeException("AuthenticationRequired", "HTTP 401")
        403 -> KomaBridgeException(
            "NetworkError",
            "La fuente rechazó la solicitud (HTTP 403): puede haber restricción regional o protección anti-bots",
        )
        404, 410 -> KomaBridgeException("ContentUnavailable", "HTTP $code")
        429 -> KomaBridgeException("RateLimited", "HTTP 429")
        else -> KomaBridgeException("NetworkError", "HTTP $code")
    }
    is IOException -> KomaBridgeException("NetworkError", message ?: javaClass.simpleName)
    is LinkageError, is ClassNotFoundException ->
        KomaBridgeException("ExtensionIncompatible", "${javaClass.simpleName}: $message")
    is UnsupportedOperationException ->
        KomaBridgeException("ContentUnavailable", message ?: "Operación no soportada por la fuente")
    else -> KomaBridgeException("UnknownError", "${javaClass.simpleName}: $message")
}
