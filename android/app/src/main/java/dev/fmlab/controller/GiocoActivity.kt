// FMLAB Emulator Android: lo schermo del gioco. Immagine dal motore nativo su una SurfaceView, tasti a schermo
// sopra (spariscono con un controller collegato), controller fisici uno per giocatore, menu col tasto Indietro.
package dev.fmlab.controller

import android.app.Activity
import android.app.AlertDialog
import android.app.Presentation
import android.hardware.display.DisplayManager
import android.view.Display
import android.content.Context
import android.graphics.Color
import android.hardware.input.InputManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import java.io.File

class GiocoActivity : Activity(), InputManager.InputDeviceListener {
    private lateinit var pad: PadView
    private lateinit var attesa: ProgressBar
    private lateinit var etichetta: TextView
    private var avviato = false
    private var tastiSchermo = 0
    private val tastiController = IntArray(4)
    private val porte = mutableListOf<Int>()       // deviceId dei controller, nell'ordine in cui si sono fatti vivi
    private var veloce = false
    private var superficieTelefono: SurfaceHolder? = null
    private var tv: Presentation? = null
    private val schermi by lazy { getSystemService(Context.DISPLAY_SERVICE) as DisplayManager }
    private val ascoltaSchermi = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(id: Int) { runOnUiThread { collegaTV() } }
        override fun onDisplayRemoved(id: Int) { runOnUiThread { if (tv?.display?.displayId == id) staccaTV() } }
        override fun onDisplayChanged(id: Int) {}
    }

    /** TV come secondo schermo vero (cavo USB-C/HDMI, Miracast/Smart View): il gioco solo sulla TV, il telefono controller. */
    private fun collegaTV() {
        if (tv != null || !prefs.getBoolean("tv", true)) return
        val d = schermi.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull() ?: return
        val p = object : Presentation(this, d) {
            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                val sv = SurfaceView(context)
                sv.holder.addCallback(object : SurfaceHolder.Callback {
                    override fun surfaceCreated(h: SurfaceHolder) { Motore.superficie(h.surface) }
                    override fun surfaceChanged(h: SurfaceHolder, f: Int, w: Int, hh: Int) { Motore.superficie(h.surface) }
                    override fun surfaceDestroyed(h: SurfaceHolder) { if (tv != null) Motore.superficie(null) }
                })
                setContentView(sv)
            }
        }
        p.setOnDismissListener { if (tv === p) staccaTV() }
        try { p.show() } catch (_: Exception) { return }
        tv = p
        pad.suTV = true
        Toast.makeText(this, getString(R.string.tv_collegata, d.name), Toast.LENGTH_SHORT).show()
    }
    private fun staccaTV() {
        val p = tv ?: return
        tv = null; pad.suTV = false
        try { p.dismiss() } catch (_: Exception) {}
        Motore.superficie(superficieTelefono?.surface)   // il gioco torna sul telefono
        Toast.makeText(this, R.string.tv_staccata, Toast.LENGTH_SHORT).show()
    }
    private var doppio = 0
    private lateinit var nome: String
    private lateinit var gioco: File
    private val prefs by lazy { getSharedPreferences("fmlab", MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        nome = intent.getStringExtra("core") ?: return finish()
        gioco = File(intent.getStringExtra("gioco") ?: return finish())
        val radice = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        val superficie = SurfaceView(this)
        superficie.holder.addCallback(object : SurfaceHolder.Callback {
            // con la TV collegata il gioco va solo lì: la superficie del telefono non si usa
            override fun surfaceCreated(h: SurfaceHolder) { superficieTelefono = h; if (tv == null) Motore.superficie(h.surface) }
            override fun surfaceChanged(h: SurfaceHolder, f: Int, w: Int, hh: Int) { superficieTelefono = h; if (tv == null) Motore.superficie(h.surface) }
            override fun surfaceDestroyed(h: SurfaceHolder) { superficieTelefono = null; if (tv == null) Motore.superficie(null) }
        })
        radice.addView(superficie, FrameLayout.LayoutParams(-1, -1))
        pad = PadView(this, trasparente = true, invia = { bit, giu -> tastiSchermo = if (giu) tastiSchermo or (1 shl bit) else tastiSchermo and (1 shl bit).inv(); invia(0) }) { menu() }
        pad.console(Emulatori.disposizione(nome), nome)
        // DS e 3DS: un dito sull'immagine (fuori dai tasti) tocca lo schermo del gioco
        doppio = when (nome) { "melonds", "desmume" -> 1; "citra", "azahar" -> 2; else -> 0 }
        Motore.schermi(doppio, prefs.getInt("schermi", 0))
        if (doppio > 0) pad.toccoLibero = { x, y, giu ->
            // lo schermo da toccare è dove lo ha messo il motore (qualunque disposizione); il core vuole le coordinate
            // sull'immagine intera, dove lo schermo di sotto è la metà bassa
            if (tv != null) {
                val t = pad.tappetino
                val px = ((x - t.left) / t.width()).coerceIn(0f, 1f); val py = ((y - t.top) / t.height()).coerceIn(0f, 1f)
                val a = Motore.areaTocco()
                Motore.tocco(((a[4] + px * (a[5] - a[4])) * 65534 - 32767).toInt(), ((0.5f + 0.5f * py) * 65534 - 32767).toInt(), giu && t.contains(x, y))
            } else {
            val a = Motore.areaTocco()
            val dentro = x >= a[0] && x <= a[2] && y >= a[1] && y <= a[3] && a[2] > a[0]
            val px = ((x - a[0]) / (a[2] - a[0])).coerceIn(0f, 1f); val py = ((y - a[1]) / (a[3] - a[1])).coerceIn(0f, 1f)
            val ix = a[4] + px * (a[5] - a[4]); val iy = if (a[6] > 0.5f) 0.5f + 0.5f * py else py
            Motore.tocco((ix * 65534 - 32767).toInt(), (iy * 65534 - 32767).toInt(), giu && dentro)
            }
        }
        radice.addView(pad, FrameLayout.LayoutParams(-1, -1))
        attesa = ProgressBar(this); radice.addView(attesa, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        etichetta = TextView(this).apply { setTextColor(Color.WHITE); textSize = 12f; setBackgroundColor(Color.argb(140, 0, 0, 0)); setPadding(12, 6, 12, 6); visibility = View.GONE }
        radice.addView(etichetta, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END))
        setContentView(radice)
        schermoIntero()
        (getSystemService(Context.INPUT_SERVICE) as InputManager).registerInputDeviceListener(this, null)
        schermi.registerDisplayListener(ascoltaSchermi, null)
        collegaTV()
        aggiornaController()
        applicaImmagine()
        // il motore apre il gioco su un filo suo (fino a qualche secondo per i dischi grandi)
        Thread {
            val core = Emulatori.libreria(this, nome).path
            val q = prefs.getInt("qualita", 1).let { if (it == 1 && tv != null && prefs.getBoolean("tvMassima", true)) 2 else it }
            val err = Motore.avvia(core, gioco.path, Archivio.bios.path, Archivio.salvataggi.path, Emulatori.opzioni(nome, q))
            runOnUiThread {
                attesa.visibility = View.GONE
                if (err != null) {
                    AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(gioco.nameWithoutExtension)
                        .setMessage(getString(R.string.gioco_non_parte, err)).setPositiveButton("OK") { _, _ -> finish() }.setCancelable(false).show()
                } else {
                    avviato = true; if (prefs.getBoolean("fps", false)) mostraFps()
                    etichetta.postDelayed({ controllaImmagine() }, 8000)
                    chiediRiprendi()
                    // giocatori 2…4 dal Wi-Fi (iPhone o Android con Controller 2)
                    Host.cambiati = { p -> invia(p) }
                    Host.avvisa = { t -> runOnUiThread { Toast.makeText(this, if (t.startsWith("−")) getString(R.string.giocatore_uscito, t.drop(2)) else getString(R.string.giocatore_entrato, t), Toast.LENGTH_SHORT).show() } }
                    Host.avvia(this, gioco.nameWithoutExtension, nome, Emulatori.disposizione(nome))
                }
            }
        }.start()
    }

    // MARK: Riprendi (come su iPhone): uscendo o andando in background si salva da solo, al rientro si chiede
    private val autoStato get() = File(Archivio.salvataggi, gioco.nameWithoutExtension + ".auto.state")
    private var filoSalva: Thread? = null
    private fun chiediRiprendi() {
        val f = autoStato
        if (!f.exists() || f.length() == 0L) return
        Motore.pausa(true)
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(gioco.nameWithoutExtension).setMessage(R.string.riprendi_chiedi)
            .setPositiveButton(R.string.riprendi_si) { _, _ ->
                Thread { val ok = Motore.caricaStato(f.path); runOnUiThread { if (!ok) Toast.makeText(this, R.string.stato_non_riuscito, Toast.LENGTH_SHORT).show(); Motore.pausa(false) } }.start()
            }
            .setNegativeButton(R.string.riprendi_no) { _, _ -> Motore.pausa(false) }.setCancelable(false).show()
    }
    /** Salva il punto in cui sei (solo se il gioco ha mostrato qualcosa), su un filo a parte per non bloccare lo schermo. */
    private fun salvaAuto(poi: (() -> Unit)? = null) {
        if (!avviato || Motore.immagini() == 0 || filoSalva?.isAlive == true) { poi?.invoke(); return }
        val f = autoStato
        filoSalva = Thread { Motore.salvaStato(f.path); poi?.let { runOnUiThread(it) } }.also { it.start() }
    }

    /** Il gioco gira ma non manda immagini: si dice perché, invece di lasciare lo schermo nero. */
    private fun controllaImmagine() {
        if (isFinishing || !avviato || Motore.immagini() > 0) return
        Motore.pausa(true)
        val consiglio = when (nome) {
            "citra", "azahar" -> getString(R.string.nero_3ds)
            "dolphin", "flycast", "mupen64plus_next_gles3", "ppsspp" -> getString(R.string.nero_gpu)
            else -> getString(R.string.nero_generico)
        }
        val log = Motore.messaggi().trim().lines().takeLast(8).joinToString("\n")
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(R.string.nero_titolo)
            .setMessage(consiglio + if (log.isNotEmpty()) "\n\n" + getString(R.string.nero_messaggi) + "\n" + log else "")
            .setPositiveButton(R.string.nero_aspetta) { _, _ -> Motore.pausa(false); etichetta.postDelayed({ controllaImmagine() }, 15000) }
            .setNegativeButton(R.string.esci_gioco) { _, _ -> finish() }.setCancelable(false).show()
    }
    /** Dove sta l'immagine del gioco sullo schermo (come la mette il motore: in verticale in alto). */
    private fun rettangoloGioco(W: Float, H: Float): android.graphics.RectF {
        var r = Motore.rapporto(); val forma = prefs.getInt("forma", 0)
        if (forma == 1 && W > H && r < 16f / 9) r = 16f / 9 else if (forma == 2) r = W / H
        var w = W; var h = w / r; if (h > H) { h = H; w = h * r }
        val y = if (H > W) 0f else (H - h) / 2
        return android.graphics.RectF((W - w) / 2, y, (W + w) / 2, y + h)
    }
    private fun applicaImmagine() = Motore.immagine(prefs.getInt("filtro", 0), prefs.getInt("effetto", 0), prefs.getInt("forma", 0))

    @Suppress("DEPRECATION")
    private fun schermoIntero() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { it.hide(WindowInsets.Type.systemBars()); it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE }
        } else window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
    }
    private fun mostraFps() {
        etichetta.visibility = View.VISIBLE
        etichetta.postDelayed(object : Runnable { override fun run() {
            if (isFinishing) return; etichetta.text = "%.1f fps".format(Motore.fps100() / 100f); etichetta.postDelayed(this, 500) } }, 500)
    }

    override fun onResume() { super.onResume(); if (avviato) Motore.pausa(false) }
    override fun onPause() { super.onPause(); if (avviato) Motore.pausa(true) }
    override fun onStop() { super.onStop(); if (!isFinishing) salvaAuto() }
    override fun onDestroy() {
        try { filoSalva?.join(4000) } catch (_: Exception) {}
        (getSystemService(Context.INPUT_SERVICE) as InputManager).unregisterInputDeviceListener(this)
        schermi.unregisterDisplayListener(ascoltaSchermi); tv?.let { tv = null; try { it.dismiss() } catch (_: Exception) {} }
        Host.cambiati = null; Host.avvisa = null; Host.ferma()
        Motore.ferma(); super.onDestroy()
    }

    // MARK: menu
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { menu() }
    private fun menu() {
        if (!avviato) return
        Motore.pausa(true)
        val stato = File(Archivio.salvataggi, gioco.nameWithoutExtension + ".state")
        val voci = arrayOf(getString(R.string.riprendi), getString(R.string.salva_stato), getString(R.string.carica_stato),
            getString(if (veloce) R.string.veloce_spento else R.string.veloce_acceso), getString(R.string.immagine), getString(R.string.esci_gioco)) +
            (if (doppio > 0) arrayOf(getString(R.string.schermi)) else arrayOf())
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(gioco.nameWithoutExtension).setItems(voci) { _, i ->
            when (i) {
                1 -> Toast.makeText(this, if (Motore.salvaStato(stato.path)) R.string.stato_salvato else R.string.stato_non_riuscito, Toast.LENGTH_SHORT).show()
                2 -> Toast.makeText(this, if (stato.exists() && Motore.caricaStato(stato.path)) R.string.stato_caricato else R.string.stato_non_riuscito, Toast.LENGTH_SHORT).show()
                3 -> { veloce = !veloce; Motore.veloce(veloce, prefs.getBoolean("muto", true)) }
                4 -> { scegliImmagine(); return@setItems }
                5 -> { salvaAuto { finish() }; return@setItems }
                6 -> { scegliSchermi(); return@setItems }
            }
            Motore.pausa(false)
        }.setOnCancelListener { Motore.pausa(false) }.show()
    }
    private fun scegliSchermi() {
        val voci = intArrayOf(R.string.schermi_auto, R.string.schermi_sopra, R.string.schermi_affiancati, R.string.schermi_grande)
        val ora = prefs.getInt("schermi", 0)
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(R.string.schermi)
            .setItems(voci.mapIndexed { i, v -> (if (i == ora) "✓ " else "") + getString(v) }.toTypedArray()) { _, i ->
                prefs.edit().putInt("schermi", i).apply(); Motore.schermi(doppio, i); Motore.pausa(false)
            }.setOnCancelListener { Motore.pausa(false) }.show()
    }
    private fun scegliImmagine() {
        val voci = arrayOf(getString(R.string.filtro_nitido), getString(R.string.filtro_liscio), getString(R.string.effetto_righe), getString(R.string.effetto_lcd), getString(R.string.effetto_nessuno), getString(R.string.forma_16_9), getString(R.string.forma_originale))
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(R.string.immagine).setItems(voci) { _, i ->
            val e = prefs.edit()
            when (i) { 0 -> e.putInt("filtro", 0); 1 -> e.putInt("filtro", 1); 2 -> e.putInt("effetto", 1); 3 -> e.putInt("effetto", 2); 4 -> e.putInt("effetto", 0); 5 -> e.putInt("forma", 1); 6 -> e.putInt("forma", 0) }
            e.apply(); applicaImmagine(); Motore.pausa(false)
        }.setOnCancelListener { Motore.pausa(false) }.show()
    }

    // MARK: controller fisici
    private fun eGamepad(d: InputDevice?) = d != null && !d.isVirtual && (d.sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD || d.sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK)
    private fun aggiornaController() {
        val ci = InputDevice.getDeviceIds().map { InputDevice.getDevice(it) }.any { eGamepad(it) }
        pad.nascosto = ci
    }
    override fun onInputDeviceAdded(id: Int) { aggiornaController(); InputDevice.getDevice(id)?.let { if (eGamepad(it)) Toast.makeText(this, getString(R.string.controller_collegato, it.name), Toast.LENGTH_SHORT).show() } }
    override fun onInputDeviceRemoved(id: Int) { val p = porte.indexOf(id); if (p >= 0) { porte.removeAt(p); tastiController.fill(0); for (k in 0 until 4) invia(k) }; aggiornaController() }
    override fun onInputDeviceChanged(id: Int) { aggiornaController() }

    private fun porta(id: Int): Int { if (id !in porte) porte += id; return porte.indexOf(id).coerceAtMost(3) }
    private fun invia(p: Int) { Motore.tasti(p, tastiController[p] or Host.tasti[p] or (if (p == 0) tastiSchermo else 0)) }

    /** Tasti Android → libretro (disposizione Nintendo: A a destra, B in basso). */
    private fun bit(code: Int) = when (code) {
        KeyEvent.KEYCODE_BUTTON_A -> Tasto.B; KeyEvent.KEYCODE_BUTTON_B -> Tasto.A
        KeyEvent.KEYCODE_BUTTON_X -> Tasto.Y; KeyEvent.KEYCODE_BUTTON_Y -> Tasto.X
        KeyEvent.KEYCODE_BUTTON_L1 -> Tasto.L; KeyEvent.KEYCODE_BUTTON_R1 -> Tasto.R
        KeyEvent.KEYCODE_BUTTON_L2 -> Tasto.L2; KeyEvent.KEYCODE_BUTTON_R2 -> Tasto.R2
        KeyEvent.KEYCODE_BUTTON_THUMBL -> 14; KeyEvent.KEYCODE_BUTTON_THUMBR -> 15
        KeyEvent.KEYCODE_BUTTON_START -> Tasto.START; KeyEvent.KEYCODE_BUTTON_SELECT -> Tasto.SELECT
        KeyEvent.KEYCODE_DPAD_UP -> Tasto.SU; KeyEvent.KEYCODE_DPAD_DOWN -> Tasto.GIU
        KeyEvent.KEYCODE_DPAD_LEFT -> Tasto.SINISTRA; KeyEvent.KEYCODE_DPAD_RIGHT -> Tasto.DESTRA
        else -> -1
    }
    override fun dispatchKeyEvent(e: KeyEvent): Boolean {
        if (e.keyCode == KeyEvent.KEYCODE_BUTTON_MODE && e.action == KeyEvent.ACTION_DOWN) { menu(); return true }
        val b = bit(e.keyCode)
        if (b < 0 || !eGamepad(e.device)) return super.dispatchKeyEvent(e)
        val p = porta(e.deviceId)
        if (e.action == KeyEvent.ACTION_DOWN) tastiController[p] = tastiController[p] or (1 shl b)
        else if (e.action == KeyEvent.ACTION_UP) tastiController[p] = tastiController[p] and (1 shl b).inv()
        invia(p); return true
    }
    override fun dispatchGenericMotionEvent(e: MotionEvent): Boolean {
        if (e.source and InputDevice.SOURCE_JOYSTICK != InputDevice.SOURCE_JOYSTICK || e.action != MotionEvent.ACTION_MOVE) return super.dispatchGenericMotionEvent(e)
        val p = porta(e.deviceId)
        fun asse(a: Int) = e.getAxisValue(a).let { if (kotlin.math.abs(it) < 0.12f) 0f else it }
        val x = asse(MotionEvent.AXIS_X); val y = asse(MotionEvent.AXIS_Y)
        Motore.levetta(p, (x * 32767).toInt(), (y * 32767).toInt())
        // croce come asse (molti controller) e levetta che fa da croce nei giochi 2D
        val hx = e.getAxisValue(MotionEvent.AXIS_HAT_X); val hy = e.getAxisValue(MotionEvent.AXIS_HAT_Y)
        val psp = nome == "ppsspp" || nome.startsWith("mupen") || nome == "citra" || nome == "azahar" || nome == "dolphin" || nome == "flycast"
        var t = tastiController[p] and ((1 shl Tasto.SU) or (1 shl Tasto.GIU) or (1 shl Tasto.SINISTRA) or (1 shl Tasto.DESTRA) or (1 shl Tasto.L2) or (1 shl Tasto.R2)).inv()
        val soglia = if (psp) 2f else 0.5f
        if (hy < -0.5f || y < -soglia) t = t or (1 shl Tasto.SU); if (hy > 0.5f || y > soglia) t = t or (1 shl Tasto.GIU)
        if (hx < -0.5f || x < -soglia) t = t or (1 shl Tasto.SINISTRA); if (hx > 0.5f || x > soglia) t = t or (1 shl Tasto.DESTRA)
        if (e.getAxisValue(MotionEvent.AXIS_LTRIGGER) > 0.5f || e.getAxisValue(MotionEvent.AXIS_BRAKE) > 0.5f) t = t or (1 shl Tasto.L2)
        if (e.getAxisValue(MotionEvent.AXIS_RTRIGGER) > 0.5f || e.getAxisValue(MotionEvent.AXIS_GAS) > 0.5f) t = t or (1 shl Tasto.R2)
        tastiController[p] = t; invia(p); return true
    }
}
