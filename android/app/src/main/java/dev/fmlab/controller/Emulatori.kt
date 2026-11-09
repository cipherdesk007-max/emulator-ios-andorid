// FMLAB Emulator Android: gli emulatori (core libretro) si installano uno per uno dalla release "core-android" del
// repository, con impronta controllata. Restano nella memoria privata dell'app.
package dev.fmlab.controller

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.zip.ZipInputStream

data class Emulatore(val nome: String, val console: String, val estensioni: List<String>, val nota: String, val file: String, val sha256: String, val misura: Long)

object Emulatori {
    private const val BASE = "https://github.com/cipherdesk007-max/emulator-ios-andorid/releases/download/core-android"
    private val principale = Handler(Looper.getMainLooper())
    var elenco: List<Emulatore> = emptyList(); private set

    fun cartella(c: Context) = File(c.filesDir, "core").apply { mkdirs() }
    fun libreria(c: Context, nome: String) = File(cartella(c), "lib${nome}_libretro.so")
    fun installato(c: Context, nome: String) = libreria(c, nome).exists()

    private fun apri(indirizzo: String): HttpURLConnection {
        var u = URL(indirizzo)
        repeat(6) {
            val k = u.openConnection() as HttpURLConnection
            k.instanceFollowRedirects = false; k.connectTimeout = 15000; k.readTimeout = 60000; k.setRequestProperty("User-Agent", "FMLAB-Emulator")
            if (k.responseCode in 300..399) { u = URL(u, k.getHeaderField("Location")); k.disconnect() } else return k
        }
        throw IllegalStateException("troppi rimandi")
    }

    /** Elenco degli emulatori disponibili (salvato anche per usarlo senza rete). */
    fun carica(c: Context, fatto: (String?) -> Unit) = Thread {
        val copia = File(c.filesDir, "core-android.json")
        val errore = try {
            val k = apri("$BASE/core-android.json"); if (k.responseCode != 200) throw IllegalStateException("HTTP ${k.responseCode}")
            copia.writeText(k.inputStream.bufferedReader().readText()); null
        } catch (e: Exception) { e.localizedMessage ?: e.toString() }
        leggi(copia)
        principale.post { fatto(if (elenco.isEmpty()) errore else null) }
    }.start()
    fun leggiSalvato(c: Context) = leggi(File(c.filesDir, "core-android.json"))
    private fun leggi(f: File) {
        if (!f.exists()) return
        try {
            val a = JSONObject(f.readText()).getJSONArray("core")
            elenco = (0 until a.length()).map { i -> val o = a.getJSONObject(i)
                Emulatore(o.getString("nome"), o.getString("console"), (0 until o.getJSONArray("estensioni").length()).map { o.getJSONArray("estensioni").getString(it) },
                    o.optString("nota"), o.getString("file"), o.getString("sha256"), o.getLong("misura")) }
        } catch (_: Exception) { }
    }

    /** Scarica, controlla l'impronta ed estrae la libreria. */
    fun installa(c: Context, e: Emulatore, avanza: (Int) -> Unit, fatto: (String?) -> Unit) = Thread {
        val zip = File(c.cacheDir, e.file)
        val errore = try {
            val k = apri("$BASE/${e.file}"); if (k.responseCode != 200) throw IllegalStateException("HTTP ${k.responseCode}")
            val md = MessageDigest.getInstance("SHA-256"); var letti = 0L; var ultimo = -1
            k.inputStream.use { i -> zip.outputStream().use { o -> val b = ByteArray(1 shl 16); var n: Int
                while (i.read(b).also { n = it } > 0) { o.write(b, 0, n); md.update(b, 0, n); letti += n
                    val p = (letti * 100 / maxOf(1, e.misura)).toInt(); if (p != ultimo) { ultimo = p; principale.post { avanza(p) } } } } }
            if (md.digest().joinToString("") { "%02x".format(it) } != e.sha256) throw IllegalStateException("impronta diversa: file non valido")
            val dest = libreria(c, e.nome); val tmp = File(dest.path + ".tmp")
            ZipInputStream(zip.inputStream()).use { z -> var v = z.nextEntry
                while (v != null) { if (v.name.endsWith(".so")) { tmp.outputStream().use { z.copyTo(it) }; break }; v = z.nextEntry } }
            if (!tmp.exists() || tmp.length() < 1024) throw IllegalStateException("libreria mancante")
            tmp.renameTo(dest); null
        } catch (x: Exception) { x.localizedMessage ?: x.toString() } finally { zip.delete() }
        principale.post { fatto(errore) }
    }.start()
    fun disinstalla(c: Context, nome: String) { libreria(c, nome).delete() }

    /** Emulatori installati che aprono questo file. */
    fun per(c: Context, file: File): List<Emulatore> {
        val est = file.extension.lowercase()
        return elenco.filter { est in it.estensioni && installato(c, it.nome) }
    }

    /** Disposizione dei tasti a schermo (come su iPhone): 0 due tasti, 1 GBA, 2 quattro tasti, 3 PlayStation. */
    fun disposizione(nome: String) = when (nome) {
        "fceumm", "gambatte" -> 0; "mgba" -> 1; "pcsx_rearmed", "ppsspp" -> 3; else -> 2
    }
    /** Opzioni dei core: grafica migliorata dove serve, PSP sulla GPU. */
    fun opzioni(nome: String, qualita: Int): Array<String> = when (nome) {
        "ppsspp" -> arrayOf("ppsspp_internal_resolution", if (qualita >= 2) "1440x816" else if (qualita == 1) "960x544" else "480x272",
            "ppsspp_texture_anisotropic_filtering", "16x", "ppsspp_frame_duplication", "enabled", "ppsspp_texture_replacement", "enabled")
        "melonds" -> arrayOf("melonds_opengl_renderer", if (qualita >= 1) "enabled" else "disabled", "melonds_opengl_resolution", if (qualita >= 2) "3x native (768x576)" else "2x native (512x384)")
        "desmume" -> arrayOf("desmume_internal_resolution", if (qualita >= 2) "768x576" else if (qualita == 1) "512x384" else "256x192")
        "pcsx_rearmed" -> arrayOf("pcsx_rearmed_neon_enhancement_enable", if (qualita >= 1) "enabled" else "disabled", "pcsx_rearmed_dithering", "disabled")
        "mupen64plus_next_gles3" -> arrayOf("mupen64plus-43screensize", if (qualita >= 2) "1920x1440" else if (qualita == 1) "1280x960" else "640x480")
        "snes9x" -> arrayOf()
        "fceumm" -> arrayOf("fceumm_palette", "smooth-fbx")
        else -> arrayOf()
    }
}
