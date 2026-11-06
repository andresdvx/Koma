package tachiyomi.core.common.util.lang

import kotlinx.coroutines.suspendCancellableCoroutine
import rx.Observable
import rx.Subscriber
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Espera el único valor emitido por un [Observable] (compatibilidad con extensiones antiguas). */
suspend fun <T> Observable<T>.awaitSingle(): T = suspendCancellableCoroutine { cont ->
    val sub = single().subscribe(object : Subscriber<T>() {
        override fun onNext(t: T) { cont.resume(t) }
        override fun onError(e: Throwable) { cont.resumeWithException(e) }
        override fun onCompleted() {}
    })
    cont.invokeOnCancellation { sub.unsubscribe() }
}
