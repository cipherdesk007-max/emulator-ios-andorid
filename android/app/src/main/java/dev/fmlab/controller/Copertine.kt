// FMLAB Emulator Android: copertine dei giochi dall'archivio libretro-thumbnails (come su iPhone), salvate nella
// memoria dell'app. Si prova il nome del file pulito (senza [..], "(Track 1)", numeri d'elenco).
package dev.fmlab.controller

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.widget.ImageView
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors

object Copertine {
    private val coda = Executors.newFixedThreadPool(3)
    private val principale = Handler(Looper.getMainLooper())
    private val memoria = LruCache<String, Bitmap>(120)
    private val mancanti = HashSet<String>()

    private fun sistema(core: String, est: String) = when (core) {
        "fceumm" -> "Nintendo - Nintendo Entertainment System"
        "gambatte" -> if (est == "gbc") "Nintendo - Game Boy Color" else "Nintendo - Game Boy"
        "mgba" -> "Nintendo - Game Boy Advance"
        "snes9x" -> "Nintendo - Super Nintendo Entertainment System"
        "genesis_plus_gx" -> when (est) { "sms" -> "Sega - Master System - Mark III"; "gg" -> "Sega - Game Gear"; else -> "Sega - Mega Drive - Genesis" }
        "pcsx_rearmed" -> "Sony - PlayStation"
        "melonds", "desmume" -> "Nintendo - Nintendo DS"
        "ppsspp" -> "Sony - PlayStation Portable"
        "mupen64plus_next_gles3" -> "Nintendo - Nintendo 64"
        "flycast" -> "Sega - Dreamcast"
        "citra", "azahar" -> "Nintendo - Nintendo 3DS"
        "dolphin" -> "Nintendo - GameCube"
        else -> null
    }
    /** Nomi da provare: quello vero, poi pulito (come fa l'archivio di libretro). */
    fun candidati(nome: String): List<String> {
        val pulito = nome.replace(Regex("""\[[^\]]*\]"""), "").replace(Regex("""^\d{1,5}\s*-\s*"""), "")
            .replace(Regex("""\s*\((Track|Disc|Disco)\s*\d+\)""", RegexOption.IGNORE_CASE), "").replace('_', ' ').replace(Regex("""\s+"""), " ").trim()
        val l = linkedSetOf(nome, pulito)
        if (!pulito.contains("(")) listOf("(Europe)", "(USA)", "(Italy)", "(Japan)").forEach { l += "$pulito $it" }
        return l.filter { it.isNotEmpty() }
    }
    private fun file(c: Context, chiave: String) = File(File(c.filesDir, "copertine").apply { mkdirs() }, chiave.hashCode().toUInt().toString(16) + ".png")

    /** Mette la copertina nell'ImageView (dalla memoria, dal disco o da Internet); se non c'è lascia l'icona della console. */
    fun metti(c: Context, v: ImageView, nome: String, core: String, est: String) {
        val sis = sistema(core, est) ?: return
        val chiave = "$sis/$nome"; v.tag = chiave
        memoria.get(chiave)?.let { v.setImageBitmap(it); v.imageAlpha = 255; return }
        if (chiave in mancanti) return
        coda.execute {
            val f = file(c, chiave)
            var bmp = if (f.exists()) BitmapFactory.decodeFile(f.path) else null
            if (bmp == null) for (n in candidati(nome)) {
                val sicuro = n.replace(Regex("""[&*/:`<>?\\|"]"""), "_")
                val url = "https://thumbnails.libretro.com/" + URLEncoder.encode(sis, "UTF-8").replace("+", "%20") + "/Named_Boxarts/" + URLEncoder.encode(sicuro, "UTF-8").replace("+", "%20") + ".png"
                try {
                    val k = URL(url).openConnection() as HttpURLConnection; k.connectTimeout = 8000; k.readTimeout = 15000; k.setRequestProperty("User-Agent", "FMLAB-Emulator")
                    if (k.responseCode == 200) { val dati = k.inputStream.readBytes(); BitmapFactory.decodeByteArray(dati, 0, dati.size)?.let { b -> f.writeBytes(dati); bmp = b } }
                    k.disconnect()
                } catch (_: Exception) { }
                if (bmp != null) break
            }
            val b = bmp
            if (b == null) { synchronized(mancanti) { mancanti += chiave }; return@execute }
            val piccola = Bitmap.createScaledBitmap(b, 144, (144f * b.height / b.width).toInt().coerceAtLeast(1), true)
            memoria.put(chiave, piccola)
            principale.post { if (v.tag == chiave) { v.setImageBitmap(piccola); v.imageAlpha = 255 } }
        }
    }
}
