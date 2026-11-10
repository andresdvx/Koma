package dev.koma.koma.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class RepositoryUrlTest {

    private val raw = "https://raw.githubusercontent.com/keiyoushi/extensions/repo"

    @Test
    fun `la carpeta del repositorio se usa tal cual`() {
        assertEquals(listOf(raw), RepositoryManager.candidatesFor("$raw/"))
    }

    @Test
    fun `la url del indice se reduce a su carpeta`() {
        assertEquals(listOf(raw), RepositoryManager.candidatesFor("$raw/index.min.json"))
    }

    @Test
    fun `la pagina de github pages sugiere el repositorio raw por convencion`() {
        val c = RepositoryManager.candidatesFor("https://keiyoushi.github.io/extensions/")
        // Primero la propia URL (por si publica el índice ahí) y luego las ramas conocidas.
        assertEquals("https://keiyoushi.github.io/extensions", c[0])
        assertEquals(raw, c[1])
        assertEquals("https://raw.githubusercontent.com/keiyoushi/extensions/main", c[2])
    }

    @Test
    fun `la pagina del repositorio en github tambien se resuelve`() {
        val c = RepositoryManager.candidatesFor("https://github.com/keiyoushi/extensions")
        assertEquals(raw, c[1])
    }

    @Test
    fun `un enlace add-repo se decodifica`() {
        val link = "mihon://add-repo?url=https%3A%2F%2Fraw.githubusercontent.com%2Fkeiyoushi%2Fextensions%2Frepo%2Findex.min.json"
        assertEquals(listOf(raw), RepositoryManager.candidatesFor(link))
        assertEquals(listOf(raw), RepositoryManager.candidatesFor(link.replace("mihon", "tachiyomi")))
    }

    @Test
    fun `solo se admite https`() {
        assertThrows(KomaBridgeException::class.java) {
            RepositoryManager.candidatesFor("http://example.com/repo")
        }
        assertThrows(KomaBridgeException::class.java) {
            RepositoryManager.candidatesFor("mihon://add-repo?url=http%3A%2F%2Fexample.com%2Frepo")
        }
    }

    @Test
    fun `un enlace add-repo sin url o un texto cualquiera se rechazan`() {
        assertThrows(KomaBridgeException::class.java) { RepositoryManager.candidatesFor("mihon://add-repo?x=1") }
        assertThrows(KomaBridgeException::class.java) { RepositoryManager.candidatesFor("hola") }
    }
}
