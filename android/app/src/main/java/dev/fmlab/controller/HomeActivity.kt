// FMLAB Emulator Android: schermata principale. Giochi, Emulatori (si installano uno per uno), Controller 2
// (questo telefono fa da controller per un iPhone), Impostazioni. Aggiornamenti dell'app in cima.
package dev.fmlab.controller

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File

class HomeActivity : Activity() {
    private val rosso = Color.rgb(230, 40, 40)
    private val fondo = Color.rgb(12, 10, 10)
    private lateinit var contenuto: LinearLayout
    private lateinit var schede: List<Button>
    private var scheda = 0
    private val prefs by lazy { getSharedPreferences("fmlab", MODE_PRIVATE) }
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.BLACK
        val radice = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(fondo); setPadding(dp(16), dp(20), dp(16), dp(8)) }
        val testa = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        testa.addView(ImageView(this).apply { setImageResource(R.drawable.logo) }, LinearLayout.LayoutParams(dp(52), dp(52)))
        testa.addView(testo("FMLAB Emulator", 24f, Color.WHITE, true).apply { setPadding(dp(12), 0, 0, 0) })
        radice.addView(testa)
        val barra = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(14), 0, dp(10)) }
        schede = listOf(R.string.scheda_giochi, R.string.scheda_emulatori, R.string.scheda_controller, R.string.scheda_impostazioni).mapIndexed { i, s ->
            Button(this).apply { text = getString(s); isAllCaps = false; textSize = 13f; setOnClickListener { if (i == 2) startActivity(Intent(this@HomeActivity, MainActivity::class.java)) else { scheda = i; mostra() } } }
        }
        schede.forEach { barra.addView(it, LinearLayout.LayoutParams(0, dp(44), 1f).apply { marginEnd = dp(4) }) }
        radice.addView(barra)
        contenuto = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        radice.addView(ScrollView(this).apply { addView(contenuto) }, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(radice)
        Emulatori.leggiSalvato(this)
        if (accessoFile()) Archivio.preparaCartelle()
        Emulatori.carica(this) { if (!isFinishing) mostra() }
        Aggiornamento.controlla(packageManager.getPackageInfo(packageName, 0).versionName ?: "0") { v -> if (v != null && !isFinishing) { versioneNuova = v; mostra() } }
    }
    override fun onResume() { super.onResume(); mostra() }

    private fun accessoFile() = if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager() else checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
    private fun chiediAccesso() {
        if (Build.VERSION.SDK_INT >= 30) {
            try { startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))) }
            catch (_: Exception) { startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)) }
        } else requestPermissions(arrayOf(android.Manifest.permission.READ_EXTERNAL_STORAGE, android.Manifest.permission.WRITE_EXTERNAL_STORAGE), 1)
    }
    override fun onRequestPermissionsResult(c: Int, p: Array<out String>, r: IntArray) { mostra() }

    private fun mostra() {
        schede.forEachIndexed { i, b -> b.background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(if (i == scheda) rosso else Color.rgb(40, 30, 30)) }; b.setTextColor(Color.WHITE) }
        contenuto.removeAllViews()
        avvisoVersione()
        when (scheda) { 0 -> giochi(); 1 -> emulatori(); else -> impostazioni() }
    }

    private var versioneNuova: String? = null
    private fun avvisoVersione() {
        val v = versioneNuova ?: return
        run {
            val box = scatola()
            box.addView(testo(getString(R.string.nuova_versione_emulatore, v), 16f, Color.WHITE, true))
            val b = bottone(getString(R.string.aggiorna)) {}
            b.setOnClickListener { b.isEnabled = false; Aggiornamento.installa(this, v, { p -> b.text = getString(R.string.scarico, p) }) { e -> b.isEnabled = true; b.text = getString(R.string.aggiorna); nota(getString(R.string.aggiornamento_fallito, e)) } }
            box.addView(b); contenuto.addView(box)
        }
    }

    // MARK: giochi
    private fun giochi() {
        if (!accessoFile()) {
            val box = scatola(); box.addView(testo(getString(R.string.accesso_spiega), 14f, Color.LTGRAY))
            box.addView(bottone(getString(R.string.accesso_consenti)) { chiediAccesso() }); contenuto.addView(box); return
        }
        if (Emulatori.elenco.none { Emulatori.installato(this, it.nome) }) {
            val box = scatola(); box.addView(testo(getString(R.string.nessun_emulatore), 14f, Color.LTGRAY))
            box.addView(bottone(getString(R.string.scheda_emulatori)) { scheda = 1; mostra() }); contenuto.addView(box); return
        }
        val est = Emulatori.elenco.filter { Emulatori.installato(this, it.nome) }.flatMap { it.estensioni }.toSet()
        val lista = Archivio.cerca(est)
        if (lista.isEmpty()) { contenuto.addView(testo(getString(R.string.nessun_gioco, Archivio.giochi.path), 14f, Color.LTGRAY).apply { setPadding(0, dp(12), 0, 0) }); return }
        for ((console, giochi) in lista.groupBy { f -> Emulatori.per(this, f).firstOrNull()?.console ?: "?" }.toSortedMap()) {
            contenuto.addView(testo(console.uppercase() + " · " + giochi.size, 13f, rosso, true).apply { setPadding(0, dp(14), 0, dp(4)) })
            for (g in giochi) contenuto.addView(riga(g.nameWithoutExtension, g.parentFile?.name ?: "") { apri(g) })
        }
        contenuto.addView(testo(getString(R.string.dove_giochi, Archivio.giochi.path), 12f, Color.GRAY).apply { setPadding(0, dp(16), 0, dp(24)) })
    }
    private fun apri(g: File) {
        var adatti = Emulatori.per(this, g)
        if (adatti.any { it.nome == "azahar" }) adatti = adatti.filter { it.nome != "citra" }   // per il 3DS Azahar è il migliore
        fun parti(e: Emulatore, file: File) = startActivity(Intent(this, GiocoActivity::class.java).putExtra("core", e.nome).putExtra("gioco", file.path))
        fun via(e: Emulatore) {
            if (!g.extension.equals("zip", true)) return parti(e, g)
            // .zip: si estrae una volta sola in FMLAB/Giochi/Estratti, poi si apre subito
            val attesa = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(g.nameWithoutExtension).setMessage(getString(R.string.estraggo, 0)).setCancelable(false).show()
            Thread {
                val r = try { Archivio.estrai(g) { p -> runOnUiThread { attesa.setMessage(getString(R.string.estraggo, p)) } } } catch (x: Exception) { null }
                runOnUiThread { attesa.dismiss(); if (r != null && r.isFile) parti(e, r) else nota(getString(R.string.zip_errore)) }
            }.start()
        }
        when {
            adatti.isEmpty() -> nota(getString(R.string.nessun_emulatore))
            adatti.size == 1 -> via(adatti[0])
            else -> AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(g.nameWithoutExtension)
                .setItems(adatti.map { it.console }.toTypedArray()) { _, i -> via(adatti[i]) }.show()
        }
    }

    // MARK: emulatori
    private fun emulatori() {
        contenuto.addView(testo(getString(R.string.emulatori_spiega), 13f, Color.GRAY).apply { setPadding(0, 0, 0, dp(10)) })
        if (Emulatori.elenco.isEmpty()) { contenuto.addView(testo(getString(R.string.emulatori_nessuno), 14f, Color.LTGRAY)); return }
        for (e in Emulatori.elenco) {
            val box = scatola()
            box.addView(testo(e.console, 16f, Color.WHITE, true))
            box.addView(testo(listOfNotNull(e.nome, "%.1f MB".format(e.misura / 1048576f), e.nota.ifEmpty { null }).joinToString(" · "), 12f, Color.GRAY))
            box.addView(testo(e.estensioni.joinToString(" ") { ".$it" }, 12f, Color.GRAY))
            val su = Emulatori.installato(this, e.nome)
            val b = bottone(getString(if (su) R.string.disinstalla else R.string.installa)) {}
            b.setOnClickListener {
                if (Emulatori.installato(this, e.nome)) { Emulatori.disinstalla(this, e.nome); mostra(); return@setOnClickListener }
                b.isEnabled = false
                Emulatori.installa(this, e, { p -> b.text = getString(R.string.scarico, p) }) { err -> if (err != null) nota(getString(R.string.installazione_fallita, err)); mostra() }
            }
            box.addView(b); contenuto.addView(box)
        }
    }

    // MARK: impostazioni
    private fun impostazioni() {
        fun scelta(titolo: Int, chiave: String, voci: List<Int>, spiega: Int) {
            val box = scatola()
            box.addView(testo(getString(titolo), 16f, Color.WHITE, true))
            box.addView(testo(getString(spiega), 12f, Color.GRAY))
            val riga = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; setPadding(0, dp(8), 0, 0) }
            voci.forEachIndexed { i, v ->
                riga.addView(Button(this).apply {
                    text = getString(v); isAllCaps = false; textSize = 12f; setTextColor(Color.WHITE)
                    background = GradientDrawable().apply { cornerRadius = dp(10).toFloat(); setColor(if (prefs.getInt(chiave, if (chiave == "qualita") 1 else 0) == i) rosso else Color.rgb(45, 30, 30)) }
                    setOnClickListener { prefs.edit().putInt(chiave, i).apply(); mostra() }
                }, LinearLayout.LayoutParams(0, dp(42), 1f).apply { marginEnd = dp(4) })
            }
            box.addView(riga); contenuto.addView(box)
        }
        scelta(R.string.qualita, "qualita", listOf(R.string.originale, R.string.migliorata, R.string.massima), R.string.qualita_spiega)
        scelta(R.string.immagine, "filtro", listOf(R.string.filtro_nitido, R.string.filtro_liscio), R.string.filtro_spiega)
        scelta(R.string.effetto, "effetto", listOf(R.string.effetto_nessuno, R.string.effetto_righe, R.string.effetto_lcd), R.string.effetto_spiega)
        scelta(R.string.forma, "forma", listOf(R.string.forma_originale, R.string.forma_16_9, R.string.forma_piena), R.string.forma_spiega)
        val box = scatola()
        for ((chiave, titolo) in listOf("muto" to R.string.muto_veloce, "fps" to R.string.mostra_fps)) {
            val si = prefs.getBoolean(chiave, chiave == "muto")
            box.addView(bottone((if (si) "✓  " else "○  ") + getString(titolo)) { prefs.edit().putBoolean(chiave, !si).apply(); mostra() })
        }
        contenuto.addView(box)
        contenuto.addView(testo(getString(R.string.cartelle_spiega, Archivio.radice.path), 12f, Color.GRAY).apply { setPadding(0, dp(12), 0, dp(24)) })
    }

    // MARK: pezzi dell'interfaccia
    private fun nota(t: String) = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setMessage(t).setPositiveButton("OK", null).show()
    private fun testo(t: String, size: Float, colore: Int, grassetto: Boolean = false) = TextView(this).apply { text = t; textSize = size; setTextColor(colore); if (grassetto) typeface = Typeface.DEFAULT_BOLD }
    private fun scatola() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL; setPadding(dp(14), dp(12), dp(14), dp(12))
        background = GradientDrawable().apply { cornerRadius = dp(16).toFloat(); setColor(Color.rgb(28, 22, 22)) }
        layoutParams = LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(10) }
    }
    private fun bottone(t: String, azione: () -> Unit) = Button(this).apply {
        text = t; isAllCaps = false; textSize = 15f; setTextColor(Color.WHITE)
        background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(Color.rgb(45, 30, 30)); setStroke(dp(1), rosso) }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)).apply { topMargin = dp(8) }
        setOnClickListener { azione() }
    }
    private fun riga(t: String, sotto: String, azione: () -> Unit) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL; setPadding(dp(14), dp(10), dp(14), dp(10)); isClickable = true
        background = GradientDrawable().apply { cornerRadius = dp(12).toFloat(); setColor(Color.rgb(28, 22, 22)) }
        layoutParams = LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(6) }
        addView(testo(t, 15f, Color.WHITE)); if (sotto.isNotEmpty()) addView(testo(sotto, 11f, Color.GRAY))
        setOnClickListener { azione() }
    }
}
