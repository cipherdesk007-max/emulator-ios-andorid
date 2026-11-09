// FMLAB Emulator Android: il telefono con il gioco aperto accoglie i controller dal Wi-Fi (iPhone con FMLAB Emulator
// › Controller 2, o un altro Android), come fa l'iPhone. Stesso protocollo (docs/PROTOCOLLO.md): TCP 47654,
// annuncio _fmlab-pad._tcp, ricerca con CHI. Giocatori 2…4 → porte 1…3.
package dev.fmlab.controller

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.provider.Settings
import java.io.InputStream
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

object Host {
    /** Tasti dei giocatori in rete per porta (0 non si usa: è il telefono). */
    val tasti = IntArray(4)
    /** Il gioco chiede di ricalcolare i tasti di una porta. */
    var cambiati: ((Int) -> Unit)? = null
    var avvisa: ((String) -> Unit)? = null

    private var server: ServerSocket? = null
    private val collegati = ConcurrentHashMap<Int, Socket>()
    private val ultimo = ConcurrentHashMap<Int, Long>()
    private var nsd: NsdManager? = null
    private var annuncio: NsdManager.RegistrationListener? = null
    @Volatile private var titolo = ""; @Volatile private var core = ""; @Volatile private var disposizione = 2
    private var nome = "Android"

    fun avvia(c: Context, titoloGioco: String, nomeCore: String, disp: Int) {
        titolo = titoloGioco; core = nomeCore; disposizione = disp
        nome = Settings.Global.getString(c.contentResolver, "device_name") ?: Build.MODEL
        if (server != null) { for ((n, s) in collegati) manda(s, stato(n, Protocollo.STATO)); return }
        Thread {
            try {
                val ss = ServerSocket(Protocollo.PORTA).apply { reuseAddress = true }; server = ss
                while (!ss.isClosed) { val s = ss.accept(); s.tcpNoDelay = true; Thread { servi(s) }.apply { isDaemon = true }.start() }
            } catch (_: Exception) { }
        }.apply { isDaemon = true }.start()
        Thread { while (server != null) { Thread.sleep(1000); val ora = System.currentTimeMillis()
            for ((n, t) in ultimo) if (ora - t > 5000) collegati[n]?.let { try { it.close() } catch (_: Exception) {} } } }.apply { isDaemon = true }.start()
        try {
            val m = c.getSystemService(Context.NSD_SERVICE) as NsdManager; nsd = m
            val info = NsdServiceInfo().apply { serviceName = nome; serviceType = Protocollo.SERVIZIO; port = Protocollo.PORTA }
            val l = object : NsdManager.RegistrationListener {
                override fun onServiceRegistered(i: NsdServiceInfo) {}; override fun onRegistrationFailed(i: NsdServiceInfo, e: Int) {}
                override fun onServiceUnregistered(i: NsdServiceInfo) {}; override fun onUnregistrationFailed(i: NsdServiceInfo, e: Int) {}
            }
            m.registerService(info, NsdManager.PROTOCOL_DNS_SD, l); annuncio = l
        } catch (_: Exception) { }
    }
    fun ferma() {
        try { server?.close() } catch (_: Exception) {}; server = null
        for (s in collegati.values) try { s.close() } catch (_: Exception) {}
        collegati.clear(); ultimo.clear(); tasti.fill(0)
        annuncio?.let { try { nsd?.unregisterService(it) } catch (_: Exception) {} }; annuncio = null
    }

    private fun stato(n: Int, tipo: Int): ByteArray {
        val c = core.toByteArray(Charsets.UTF_8).take(30).toByteArray()
        val t = titolo.toByteArray(Charsets.UTF_8).take(200).toByteArray()
        return Protocollo.messaggio(tipo, byteArrayOf(n.toByte(), disposizione.toByte(), c.size.toByte()) + c + t)
    }
    private fun manda(s: Socket, m: ByteArray) = synchronized(s) { try { s.getOutputStream().apply { write(m); flush() } } catch (_: Exception) {} }

    private fun servi(s: Socket) {
        var numero = 0
        try {
            val i: InputStream = s.getInputStream(); val buf = ByteArray(256)
            while (true) {
                val n = i.read(); if (n < 0) break; if (n == 0) continue
                var letti = 0; while (letti < n) { val k = i.read(buf, letti, n - letti); if (k < 0) break; letti += k }
                if (letti < n) break
                when (buf[0].toInt() and 0xFF) {
                    Protocollo.CIAO -> if (numero == 0) {
                        val libero = (2..4).firstOrNull { it !in collegati.keys } ?: 0
                        if (libero == 0) { manda(s, Protocollo.messaggio(Protocollo.BENVENUTO, byteArrayOf(0))); break }
                        numero = libero; collegati[libero] = s; ultimo[libero] = System.currentTimeMillis()
                        val chi = if (n > 2) String(buf, 2, n - 2, Charsets.UTF_8) else "Controller"
                        manda(s, stato(libero, Protocollo.BENVENUTO)); avvisa?.invoke("$chi → $libero")
                    }
                    Protocollo.TASTI -> if (numero > 0 && n >= 7) {
                        val t = (buf[1].toInt() and 0xFF) or ((buf[2].toInt() and 0xFF) shl 8)
                        val x = ((buf[3].toInt() and 0xFF) or (buf[4].toInt() shl 8)).toShort().toInt()
                        val y = ((buf[5].toInt() and 0xFF) or (buf[6].toInt() shl 8)).toShort().toInt()
                        tasti[numero - 1] = t; ultimo[numero] = System.currentTimeMillis()
                        if (x != 0 || y != 0) Motore.levetta(numero - 1, x, y)
                        cambiati?.invoke(numero - 1)
                    }
                    Protocollo.PING -> if (numero > 0) { ultimo[numero] = System.currentTimeMillis(); manda(s, Protocollo.messaggio(Protocollo.PING)) }
                    Protocollo.CHI -> if (numero == 0) manda(s, Protocollo.messaggio(Protocollo.SONO, nome.toByteArray(Charsets.UTF_8).take(60).toByteArray()))
                }
            }
        } catch (_: Exception) { }
        if (numero > 0 && collegati[numero] === s) { collegati.remove(numero); ultimo.remove(numero); tasti[numero - 1] = 0; cambiati?.invoke(numero - 1); avvisa?.invoke("− $numero") }
        try { s.close() } catch (_: Exception) {}
    }
}
