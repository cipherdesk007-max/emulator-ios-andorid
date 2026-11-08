// FMLAB Controller: cerca sul Wi-Fi i telefoni con FMLAB Emulator aperto e si collega come Controller 2…4.
package dev.fmlab.controller

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView

class MainActivity : Activity() {
    private data class Trovato(val nome: String, val indirizzo: String, val porta: Int)

    private lateinit var elenco: LinearLayout
    private lateinit var stato: TextView
    private lateinit var cercando: LinearLayout
    private lateinit var campo: EditText
    private lateinit var avvisoVersione: LinearLayout
    private var versioneNuova: String? = null
    private var nsd: NsdManager? = null
    private var ricerca: NsdManager.DiscoveryListener? = null
    private var multicast: WifiManager.MulticastLock? = null
    private val trovati = linkedMapOf<String, Trovato>()
    private val daRisolvere = ArrayDeque<NsdServiceInfo>()
    private var risolvendo = false
    private val rosso = Color.rgb(230, 40, 40)

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.BLACK
        val radice = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setBackgroundColor(Color.rgb(12, 10, 10)); setPadding(dp(20), dp(24), dp(20), dp(24))
        }
        radice.addView(ImageView(this).apply { setImageResource(R.drawable.logo); adjustViewBounds = true },
            LinearLayout.LayoutParams(dp(120), dp(120)).apply { gravity = Gravity.CENTER_HORIZONTAL })
        radice.addView(testo(getString(R.string.app_name), 26f, Color.WHITE, true).apply { gravity = Gravity.CENTER })
        radice.addView(testo(getString(R.string.sottotitolo), 15f, Color.LTGRAY).apply { gravity = Gravity.CENTER; setPadding(0, dp(4), 0, dp(18)) })

        avvisoVersione = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; visibility = View.GONE; setPadding(dp(14), dp(12), dp(14), dp(12))
            background = GradientDrawable().apply { cornerRadius = dp(16).toFloat(); setColor(Color.rgb(40, 18, 18)); setStroke(dp(1), rosso) } }
        radice.addView(avvisoVersione, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(18) })
        radice.addView(testo(getString(R.string.partite_vicine), 13f, rosso, true))
        cercando = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; setPadding(0, dp(10), 0, dp(10))
            addView(ProgressBar(context).apply { isIndeterminate = true }, LinearLayout.LayoutParams(dp(26), dp(26)))
            addView(testo(getString(R.string.cerco), 15f, Color.LTGRAY).apply { setPadding(dp(12), 0, 0, 0) })
        }
        radice.addView(cercando)
        elenco = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        radice.addView(elenco)
        radice.addView(bottone("↻  " + getString(R.string.cerca_ancora)) { trovati.clear(); disegnaElenco(); cercaNellaRete() })
        radice.addView(testo(getString(R.string.nota_partite), 13f, Color.GRAY).apply { setPadding(0, dp(6), 0, dp(20)) })

        radice.addView(testo(getString(R.string.con_indirizzo), 13f, rosso, true))
        campo = EditText(this).apply {
            hint = getString(R.string.indirizzo_esempio); setTextColor(Color.WHITE); setHintTextColor(Color.GRAY)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI; isSingleLine = true
            setText(getSharedPreferences("fmlab", MODE_PRIVATE).getString("indirizzo", ""))
        }
        radice.addView(campo)
        radice.addView(bottone(getString(R.string.collegati)) {
            val ind = campo.text.toString().trim()
            if (ind.isNotEmpty()) { getSharedPreferences("fmlab", MODE_PRIVATE).edit().putString("indirizzo", ind).apply(); collega(ind, Protocollo.PORTA) }
        })
        radice.addView(testo(getString(R.string.nota_indirizzo), 13f, Color.GRAY).apply { setPadding(0, dp(6), 0, dp(16)) })
        stato = testo("", 15f, Color.rgb(255, 170, 60)).apply { visibility = View.GONE }
        radice.addView(stato)
        radice.addView(testo(getString(R.string.versione, packageManager.getPackageInfo(packageName, 0).versionName), 12f, Color.DKGRAY).apply { gravity = Gravity.CENTER; setPadding(0, dp(24), 0, 0) })
        setContentView(ScrollView(this).apply { setBackgroundColor(Color.rgb(12, 10, 10)); addView(radice) })
    }

    override fun onResume() {
        super.onResume()
        Collegamento.ascolta = { e ->
            when (e) {
                is Evento.Collegato -> { stato.visibility = View.GONE; startActivity(Intent(this, PadActivity::class.java)) }
                is Evento.Pieno -> mostraStato(getString(R.string.pieno))
                is Evento.Perso -> mostraStato(if (e.motivo.isEmpty()) getString(R.string.perso) else getString(R.string.non_collegato, e.motivo))
            }
        }
        cerca(); cercaNellaRete()
        val attuale = packageManager.getPackageInfo(packageName, 0).versionName ?: "0"
        Aggiornamento.controlla(attuale) { v -> if (v != null) mostraVersione(v) }
    }

    private fun mostraVersione(v: String) {
        if (versioneNuova == v) return
        versioneNuova = v
        avvisoVersione.removeAllViews(); avvisoVersione.visibility = View.VISIBLE
        avvisoVersione.addView(testo(getString(R.string.nuova_versione, v), 17f, Color.WHITE, true))
        avvisoVersione.addView(testo(getString(R.string.nuova_versione_nota), 13f, Color.LTGRAY).apply { setPadding(0, dp(4), 0, 0) })
        val tasto = bottone(getString(R.string.aggiorna)) {}
        tasto.setOnClickListener {
            tasto.isEnabled = false
            Aggiornamento.installa(this, v, { p -> tasto.text = getString(R.string.scarico, p) }) { e -> tasto.isEnabled = true; tasto.text = getString(R.string.aggiorna); mostraStato(getString(R.string.aggiornamento_fallito, e)) }
        }
        avvisoVersione.addView(tasto)
    }
    override fun onPause() { super.onPause(); smetti() }

    private fun mostraStato(t: String) { stato.text = t; stato.visibility = View.VISIBLE }

    private fun collega(indirizzo: String, porta: Int) {
        mostraStato(getString(R.string.collego))
        val nome = Settings.Global.getString(contentResolver, "device_name") ?: Build.MODEL
        Collegamento.collega(indirizzo, porta, nome)
    }

    // MARK: ricerca sul Wi-Fi (Bonjour/mDNS, come fa l'iPhone)
    private fun cerca() {
        trovati.clear(); disegnaElenco()
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicast = wifi.createMulticastLock("fmlab").apply { setReferenceCounted(false); acquire() }
        val m = getSystemService(Context.NSD_SERVICE) as NsdManager; nsd = m
        val l = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {}
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { runOnUiThread { mostraStato(getString(R.string.ricerca_fallita)) } }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
            override fun onServiceFound(s: NsdServiceInfo) { runOnUiThread { daRisolvere.addLast(s); risolviProssimo() } }
            override fun onServiceLost(s: NsdServiceInfo) { runOnUiThread { trovati.remove(s.serviceName); disegnaElenco() } }
        }
        ricerca = l
        try { m.discoverServices(Protocollo.SERVIZIO, NsdManager.PROTOCOL_DNS_SD, l) } catch (_: Exception) { mostraStato(getString(R.string.ricerca_fallita)) }
    }
    @Volatile private var giroScansione = 0
    /** Funziona anche quando la ricerca automatica è bloccata (l'iPhone dentro LiveContainer non si annuncia). */
    private fun cercaNellaRete() {
        val (prefisso, mio) = Scansione.reteLocale(this) ?: return
        val giro = ++giroScansione
        val pool = java.util.concurrent.Executors.newFixedThreadPool(40)
        for (k in 1..254) {
            val ip = prefisso + k; if (ip == mio) continue
            pool.execute {
                if (giro != giroScansione) return@execute
                Scansione.prova(ip)?.let { nome -> runOnUiThread { if (trovati.values.none { it.indirizzo == ip || it.nome == nome }) { trovati[nome] = Trovato(nome, ip, Protocollo.PORTA); disegnaElenco() } } }
            }
        }
        pool.shutdown()
    }
    private fun smetti() {
        giroScansione++
        ricerca?.let { try { nsd?.stopServiceDiscovery(it) } catch (_: Exception) { } }
        ricerca = null; daRisolvere.clear(); risolvendo = false
        multicast?.release(); multicast = null
    }
    /** Android risolve un servizio alla volta: si mettono in fila. */
    @Suppress("DEPRECATION")
    private fun risolviProssimo() {
        val m = nsd ?: return
        if (risolvendo) return
        val s = daRisolvere.removeFirstOrNull() ?: return
        risolvendo = true
        m.resolveService(s, object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) { runOnUiThread { risolvendo = false; risolviProssimo() } }
            override fun onServiceResolved(info: NsdServiceInfo) {
                val ind = if (Build.VERSION.SDK_INT >= 34) info.hostAddresses.firstOrNull { it is java.net.Inet4Address }?.hostAddress ?: info.hostAddresses.firstOrNull()?.hostAddress
                          else info.host?.hostAddress
                runOnUiThread {
                    if (ind != null) { trovati[info.serviceName] = Trovato(info.serviceName, ind, info.port); disegnaElenco() }
                    risolvendo = false; risolviProssimo()
                }
            }
        })
    }
    private fun disegnaElenco() {
        elenco.removeAllViews()
        cercando.visibility = if (trovati.isEmpty()) View.VISIBLE else View.GONE
        for (t in trovati.values) elenco.addView(bottone("📱  " + t.nome) { collega(t.indirizzo, t.porta) })
    }

    private fun testo(t: String, size: Float, colore: Int, grassetto: Boolean = false) = TextView(this).apply {
        text = t; textSize = size; setTextColor(colore); if (grassetto) typeface = Typeface.DEFAULT_BOLD
    }
    private fun bottone(t: String, azione: () -> Unit) = Button(this).apply {
        text = t; isAllCaps = false; textSize = 16f; setTextColor(Color.WHITE)
        background = GradientDrawable().apply { cornerRadius = dp(14).toFloat(); setColor(Color.rgb(45, 30, 30)); setStroke(dp(1), rosso) }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin = dp(8) }
        setOnClickListener { azione() }
    }
}
