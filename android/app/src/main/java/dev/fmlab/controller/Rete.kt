// FMLAB Controller: collegamento al telefono con il gioco (FMLAB Emulator su iPhone), stesso protocollo di
// ios/FMLABEmulator/Rete/FMLABRete.swift (docs/PROTOCOLLO.md): TCP 47654, messaggi [lunghezza][tipo][dati].
package dev.fmlab.controller

import android.os.Handler
import android.os.Looper
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

object Protocollo {
    const val PORTA = 47654
    const val SERVIZIO = "_fmlab-pad._tcp"
    const val VERSIONE = 1
    const val CIAO = 0x01
    const val TASTI = 0x02
    const val PING = 0x03
    const val CHI = 0x04
    const val SONO = 0x84
    const val BENVENUTO = 0x81
    const val STATO = 0x82

    fun messaggio(tipo: Int, dati: ByteArray = ByteArray(0)): ByteArray {
        val n = minOf(dati.size, 254)
        val m = ByteArray(n + 2)
        m[0] = (n + 1).toByte(); m[1] = tipo.toByte()
        System.arraycopy(dati, 0, m, 2, n)
        return m
    }
}

/** Ricerca senza Bonjour: prova tutti gli indirizzi del Wi-Fi sulla porta di FMLAB (come fa l'iPhone). */
object Scansione {
    fun prova(ip: String): String? = try {
        Socket().use { s ->
            s.connect(InetSocketAddress(ip, Protocollo.PORTA), 700); s.soTimeout = 1500; s.tcpNoDelay = true
            s.getOutputStream().apply { write(Protocollo.messaggio(Protocollo.CHI)); flush() }
            val i = s.getInputStream(); val n = i.read(); val t = i.read()
            if (n > 1 && t == Protocollo.SONO) { val b = ByteArray(n - 1); var k = 0; while (k < b.size) { val r = i.read(b, k, b.size - k); if (r < 0) break; k += r }; String(b, 0, k, Charsets.UTF_8) } else null
        }
    } catch (_: Exception) { null }

    /** Prima parte dell'indirizzo (es. 192.168.1.) e il proprio numero, dal Wi-Fi attivo. */
    fun reteLocale(c: android.content.Context): Pair<String, String>? {
        val cm = c.getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        val lp = cm.getLinkProperties(cm.activeNetwork) ?: return null
        val a = lp.linkAddresses.firstOrNull { it.address is java.net.Inet4Address }?.address?.hostAddress ?: return null
        return a.substringBeforeLast('.') + "." to a
    }
}

/** Tasti (stessi numeri di libretro). */
object Tasto {
    const val B = 0; const val Y = 1; const val SELECT = 2; const val START = 3
    const val SU = 4; const val GIU = 5; const val SINISTRA = 6; const val DESTRA = 7
    const val A = 8; const val X = 9; const val L = 10; const val R = 11; const val L2 = 12; const val R2 = 13
}

sealed class Evento {
    data class Collegato(val giocatore: Int, val disposizione: Int, val core: String, val titolo: String) : Evento()
    object Pieno : Evento()
    data class Perso(val motivo: String) : Evento()
}

/** Un solo collegamento per volta, condiviso dalle due schermate. */
object Collegamento {
    private val principale = Handler(Looper.getMainLooper())
    private val invio = Executors.newSingleThreadScheduledExecutor()
    @Volatile private var presa: Socket? = null
    @Volatile private var uscita: OutputStream? = null
    private var battito: ScheduledFuture<*>? = null
    private var tasti = 0
    @Volatile var ultimo: Evento.Collegato? = null; private set
    var ascolta: ((Evento) -> Unit)? = null

    private fun avvisa(e: Evento) = principale.post { if (e is Evento.Collegato) ultimo = e; ascolta?.invoke(e) }

    fun collega(indirizzo: String, porta: Int, nome: String) {
        chiudi()
        Thread {
            try {
                val s = Socket()
                s.tcpNoDelay = true
                s.connect(InetSocketAddress(indirizzo, porta), 6000)
                presa = s; uscita = s.getOutputStream()
                val n = nome.toByteArray(Charsets.UTF_8).let { if (it.size > 40) it.copyOf(40) else it }
                scrivi(Protocollo.messaggio(Protocollo.CIAO, byteArrayOf(Protocollo.VERSIONE.toByte()) + n))
                battito = invio.scheduleWithFixedDelay({ inviaTasti() }, 1, 1, TimeUnit.SECONDS)
                leggi(s.getInputStream(), s)
            } catch (e: Exception) {
                avvisa(Evento.Perso(e.localizedMessage ?: e.toString()))
                chiudi()
            }
        }.apply { isDaemon = true }.start()
    }

    private fun leggi(ingresso: InputStream, s: Socket) {
        val buf = ByteArray(256)
        while (presa === s) {
            val n = ingresso.read(); if (n < 0) break
            if (n == 0) continue
            var letti = 0
            while (letti < n) { val k = ingresso.read(buf, letti, n - letti); if (k < 0) break; letti += k }
            if (letti < n) break
            val tipo = buf[0].toInt() and 0xFF
            if (tipo == Protocollo.BENVENUTO || tipo == Protocollo.STATO) {
                val g = if (n > 1) buf[1].toInt() and 0xFF else 0
                if (g == 0) { avvisa(Evento.Pieno); chiudi(); return }
                val disp = if (n > 2) buf[2].toInt() and 0xFF else 2
                val lc = if (n > 3) buf[3].toInt() and 0xFF else 0
                val core = if (n >= 4 + lc) String(buf, 4, lc, Charsets.UTF_8) else ""
                val titolo = if (n > 4 + lc) String(buf, 4 + lc, n - 4 - lc, Charsets.UTF_8) else ""
                avvisa(Evento.Collegato(g, disp, core, titolo))
            }
        }
        if (presa === s) { avvisa(Evento.Perso("")); chiudi() }
    }

    /** Un tasto giù o su: si manda solo se cambia qualcosa. */
    fun tasto(bit: Int, premuto: Boolean) = invio.execute {
        val nuovo = if (premuto) tasti or (1 shl bit) else tasti and (1 shl bit).inv()
        if (nuovo != tasti) { tasti = nuovo; inviaTasti() }
    }
    fun rilasciaTutto() = invio.execute { if (tasti != 0) { tasti = 0; inviaTasti() } }

    private fun inviaTasti() {
        val t = tasti
        scrivi(Protocollo.messaggio(Protocollo.TASTI, byteArrayOf((t and 0xFF).toByte(), ((t shr 8) and 0xFF).toByte(), 0, 0, 0, 0)))
    }
    private fun scrivi(m: ByteArray) {
        try { uscita?.apply { write(m); flush() } } catch (_: Exception) { }
    }

    fun chiudi() {
        battito?.cancel(false); battito = null
        val s = presa; presa = null; uscita = null; ultimo = null
        invio.execute { tasti = 0 }
        try { s?.close() } catch (_: Exception) { }
    }
}
