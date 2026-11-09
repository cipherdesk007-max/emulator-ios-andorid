// FMLAB Emulator Android: cartelle visibili nel telefono (FMLAB/Giochi, Salvataggi, BIOS) e ricerca dei giochi.
package dev.fmlab.controller

import android.os.Environment
import java.io.File
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

object Archivio {
    val radice: File get() = File(Environment.getExternalStorageDirectory(), "FMLAB")
    val giochi: File get() = File(radice, "Giochi").apply { mkdirs() }
    val salvataggi: File get() = File(radice, "Salvataggi").apply { mkdirs() }
    val bios: File get() = File(radice, "BIOS").apply { mkdirs() }

    /** Cartelle per le chiavi 3DS (dal proprio 3DS: aes_keys.txt per Citra, keys.txt per Azahar) e il LEGGIMI. */
    fun preparaCartelle() {
        val leggimi = """FMLAB Emulator · 3DS

IT  I giochi 3DS DECRIPTATI partono così. Per i giochi criptati servono le chiavi del TUO 3DS (con GodMode9):
    Azahar: metti keys.txt (o aes_keys.txt) in FMLAB/BIOS/azahar/sysdata  ·  Citra: aes_keys.txt in FMLAB/Salvataggi/Citra/sysdata
    FMLAB non include e non scarica chiavi, giochi o BIOS.
EN  DECRYPTED 3DS games start as they are. Encrypted games need the keys of YOUR 3DS (dumped with GodMode9):
    Azahar: keys.txt (or aes_keys.txt) in FMLAB/BIOS/azahar/sysdata  ·  Citra: aes_keys.txt in FMLAB/Salvataggi/Citra/sysdata
"""
        for (d in listOf(File(bios, "azahar/sysdata"), File(bios, "citra/sysdata"), File(salvataggi, "Citra/sysdata"))) {
            d.mkdirs(); val f = File(d, "LEGGIMI - README.txt"); if (!f.exists()) try { f.writeText(leggimi) } catch (_: Exception) {}
        }
    }

    /** Nome del gioco dentro uno .zip (il primo file che non sia un LEGGIMI), senza estrarlo. */
    fun dentroZip(z: File): String? = try { ZipFile(z).use { f -> f.entries().asSequence().filter { !it.isDirectory && !it.name.substringAfterLast('/').startsWith(".") }
        .map { it.name }.filter { n -> n.substringAfterLast('.').lowercase() !in setOf("txt", "nfo", "jpg", "png", "url", "sfv", "md") }.maxByOrNull { n -> f.getEntry(n).size } } } catch (_: Exception) { null }

    /** Estrae lo .zip una volta sola in FMLAB/Giochi/Estratti e ridà il gioco da aprire. */
    fun estrai(z: File, avanza: (Int) -> Unit): File {
        val dest = File(giochi, "Estratti/" + z.nameWithoutExtension)
        val fatto = File(dest, ".pronto"); val chiave = "${z.length()}|${z.lastModified()}"
        if (!(fatto.exists() && fatto.readText() == chiave)) {
            val tmp = File(giochi, "Estratti/.in-corso-" + z.nameWithoutExtension); tmp.deleteRecursively(); tmp.mkdirs()
            val totale = maxOf(1L, z.length()); var letti = 0L
            ZipInputStream(z.inputStream().buffered()).use { zi -> var v = zi.nextEntry
                while (v != null) {
                    val nome = v.name.substringAfterLast('/')
                    if (!v.isDirectory && nome.isNotEmpty() && !nome.startsWith(".")) File(tmp, nome).outputStream().use { o -> val b = ByteArray(1 shl 16); var n: Int
                        while (zi.read(b).also { n = it } > 0) { o.write(b, 0, n); letti += n; avanza((letti * 100 / totale).coerceAtMost(99).toInt()) } }
                    v = zi.nextEntry
                } }
            File(tmp, ".pronto").writeText(chiave); dest.deleteRecursively(); tmp.renameTo(dest)
        }
        val f = dest.listFiles()?.filter { !it.name.startsWith(".") } ?: emptyList()
        return f.firstOrNull { it.extension.lowercase() in setOf("cue", "m3u") } ?: f.maxByOrNull { it.length() } ?: dest
    }

    /** Giochi in FMLAB/Giochi e in Download (fino a 3 livelli), solo i file che un emulatore conosce. */
    fun cerca(estensioni: Set<String>): List<File> {
        val dove = listOf(giochi, Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS))
        val trovati = mutableListOf<File>()
        for (d in dove) d.walkTopDown().onEnter { it.name != "Estratti" }.maxDepth(3).filter { it.isFile && !it.name.startsWith(".") &&
            (it.extension.lowercase() in estensioni || (it.extension.equals("zip", true) && dentroZip(it)?.substringAfterLast('.')?.lowercase() in estensioni)) }.forEach { f ->
            // le tracce .bin di un disco con .cue accanto non sono giochi a sé
            if (f.extension.lowercase() == "bin" && f.parentFile?.listFiles()?.any { it.extension.lowercase() == "cue" } == true) return@forEach
            trovati += f
        }
        return trovati.distinctBy { it.canonicalPath }.sortedBy { it.nameWithoutExtension.lowercase() }
    }
}
