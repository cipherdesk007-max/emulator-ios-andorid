// FMLAB Emulator Android: il motore nativo (app/src/main/cpp/fmlab.c).
package dev.fmlab.controller

import android.view.Surface

object Motore {
    init { System.loadLibrary("fmlab") }
    /** null se il gioco è partito, altrimenti il motivo. */
    @JvmStatic external fun avvia(core: String, gioco: String, sistema: String, salvataggi: String, opzioni: Array<String>): String?
    @JvmStatic external fun superficie(s: Surface?)
    @JvmStatic external fun tasti(porta: Int, maschera: Int)
    @JvmStatic external fun levetta(porta: Int, x: Int, y: Int)
    @JvmStatic external fun tocco(x: Int, y: Int, giu: Boolean)
    @JvmStatic external fun pausa(si: Boolean)
    @JvmStatic external fun veloce(si: Boolean, muto: Boolean)
    @JvmStatic external fun immagine(filtro: Int, effetto: Int, forma: Int)
    @JvmStatic external fun fps100(): Int
    @JvmStatic external fun rapporto(): Float
    @JvmStatic external fun salvaStato(percorso: String): Boolean
    @JvmStatic external fun caricaStato(percorso: String): Boolean
    @JvmStatic external fun ferma()
    /** Fotogrammi con un'immagine vera da quando è partito il gioco (0 = schermo nero). */
    @JvmStatic external fun immagini(): Int
    /** Avvisi ed errori del core (ultime righe). */
    @JvmStatic external fun messaggi(): String
    @JvmStatic external fun usaGpu(): Boolean
}
