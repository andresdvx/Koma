package eu.kanade.tachiyomi.network.interceptor

import android.util.Log
import okhttp3.Interceptor
import okhttp3.Response

/** Diagnóstico: registra host, ruta, código y cabeceras de bloqueo de respuestas fallidas. Sin query ni cookies. */
class FailureLogInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val response = chain.proceed(chain.request())
        if (!response.isSuccessful) {
            val u = response.request.url
            Log.w(
                "KomaNet",
                "${response.code} ${u.host}${u.encodedPath} server=${response.header("Server")} " +
                    "cf-mitigated=${response.header("cf-mitigated")} ua=${response.request.header("User-Agent")?.take(40)}",
            )
        }
        return response
    }
}
