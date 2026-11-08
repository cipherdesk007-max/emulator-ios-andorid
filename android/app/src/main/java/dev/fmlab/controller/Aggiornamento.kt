// FMLAB Controller: aggiornamenti dall'app. Guarda VERSIONE.txt della release "ultima"; se c'è una versione più
// nuova scarica l'APK e lo passa all'installatore di Android (PackageInstaller): un tocco su "Aggiorna" e Android
// chiede conferma. La firma è sempre la stessa, quindi si installa sopra e i dati restano.
package dev.fmlab.controller

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import java.net.HttpURLConnection
import java.net.URL

object Aggiornamento {
    private const val BASE = "https://github.com/cipherdesk007-max/emulator-ios-andorid/releases/download"
    private val principale = Handler(Looper.getMainLooper())

    fun piuNuova(a: String, b: String): Boolean {
        val x = a.split('.').map { it.toIntOrNull() ?: 0 }; val y = b.split('.').map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(x.size, y.size)) { val p = x.getOrElse(i) { 0 }; val q = y.getOrElse(i) { 0 }; if (p != q) return p > q }
        return false
    }

    private fun apri(indirizzo: String): HttpURLConnection {
        var u = URL(indirizzo)
        repeat(6) {   // GitHub rimanda a un altro indirizzo per il file vero
            val c = u.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false; c.connectTimeout = 12000; c.readTimeout = 30000
            c.setRequestProperty("User-Agent", "FMLAB-Controller")
            if (c.responseCode in 300..399) { u = URL(u, c.getHeaderField("Location")); c.disconnect() } else return c
        }
        throw IllegalStateException("troppi rimandi")
    }

    /** La versione nuova, se c'è (sul filo principale). */
    fun controlla(attuale: String, fatto: (String?) -> Unit) = Thread {
        val v = try { apri("$BASE/ultima/VERSIONE.txt").let { c -> if (c.responseCode == 200) c.inputStream.bufferedReader().readText().trim() else null } } catch (_: Exception) { null }
        val nuova = v?.takeIf { it.length < 16 && it.all { ch -> ch.isDigit() || ch == '.' } && piuNuova(it, attuale) }
        principale.post { fatto(nuova) }
    }.start()

    /** Scarica l'APK della versione e lo dà all'installatore di Android. */
    fun installa(a: Activity, versione: String, avanza: (Int) -> Unit, errore: (String) -> Unit) = Thread {
        try {
            val c = apri("$BASE/v$versione/FMLAB-Controller.apk")
            if (c.responseCode != 200) throw IllegalStateException("HTTP ${c.responseCode}")
            val totale = c.contentLengthLong
            val pi = a.packageManager.packageInstaller
            val parametri = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            if (Build.VERSION.SDK_INT >= 26) parametri.setAppPackageName(a.packageName)
            val id = pi.createSession(parametri)
            pi.openSession(id).use { s ->
                s.openWrite("FMLAB-Controller.apk", 0, if (totale > 0) totale else -1).use { out ->
                    c.inputStream.use { inp ->
                        val b = ByteArray(1 shl 16); var letti = 0L; var n: Int; var ultimo = -1
                        while (inp.read(b).also { n = it } > 0) {
                            out.write(b, 0, n); letti += n
                            val p = if (totale > 0) (letti * 100 / totale).toInt() else 0
                            if (p != ultimo) { ultimo = p; principale.post { avanza(p) } }
                        }
                    }
                    s.fsync(out)
                }
                val flag = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                val p = PendingIntent.getBroadcast(a, id, Intent(a, EsitoInstallazione::class.java), flag)
                s.commit(p.intentSender)
            }
        } catch (e: Exception) {
            principale.post { errore(e.localizedMessage ?: e.toString()) }
        }
    }.start()
}

/** Risposta dell'installatore: se serve la conferma dell'utente, si apre la schermata di Android. */
class EsitoInstallazione : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        when (i.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val conferma = (if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java) else i.getParcelableExtra(Intent.EXTRA_INTENT)) ?: return
                conferma.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                c.startActivity(conferma)
            }
            PackageInstaller.STATUS_SUCCESS -> {}
            else -> Toast.makeText(c, c.getString(R.string.aggiornamento_fallito, i.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""), Toast.LENGTH_LONG).show()
        }
    }
}
