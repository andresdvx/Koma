package eu.kanade.tachiyomi.network.interceptor

import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * Versión mínima: las extensiones exigen que exista en el cliente por defecto.
 * Aún no resuelve desafíos de Cloudflare con WebView; los detecta y falla con un
 * mensaje claro en lugar de devolver una página de bloqueo como si fuera contenido.
 */
class CloudflareInterceptor : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val response = chain.proceed(chain.request())
        if (response.code in ERROR_CODES && response.header("Server") in SERVER_CHECK) {
            response.close()
            throw IOException("Cloudflare bloqueó la solicitud (desafío no soportado todavía)")
        }
        return response
    }

    private companion object {
        val ERROR_CODES = listOf(403, 503)
        val SERVER_CHECK = listOf("cloudflare-nginx", "cloudflare")
    }
}
