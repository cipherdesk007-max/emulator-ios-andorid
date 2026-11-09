// FMLAB Emulator Android: cartelle visibili nel telefono (FMLAB/Giochi, Salvataggi, BIOS) e ricerca dei giochi.
package dev.fmlab.controller

import android.os.Environment
import java.io.File

object Archivio {
    val radice: File get() = File(Environment.getExternalStorageDirectory(), "FMLAB")
    val giochi: File get() = File(radice, "Giochi").apply { mkdirs() }
    val salvataggi: File get() = File(radice, "Salvataggi").apply { mkdirs() }
    val bios: File get() = File(radice, "BIOS").apply { mkdirs() }

    /** Giochi in FMLAB/Giochi e in Download (fino a 3 livelli), solo i file che un emulatore conosce. */
    fun cerca(estensioni: Set<String>): List<File> {
        val dove = listOf(giochi, Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS))
        val trovati = mutableListOf<File>()
        for (d in dove) d.walkTopDown().maxDepth(3).filter { it.isFile && !it.name.startsWith(".") && it.extension.lowercase() in estensioni }.forEach { f ->
            // le tracce .bin di un disco con .cue accanto non sono giochi a sé
            if (f.extension.lowercase() == "bin" && f.parentFile?.listFiles()?.any { it.extension.lowercase() == "cue" } == true) return@forEach
            trovati += f
        }
        return trovati.distinctBy { it.canonicalPath }.sortedBy { it.nameWithoutExtension.lowercase() }
    }
}
