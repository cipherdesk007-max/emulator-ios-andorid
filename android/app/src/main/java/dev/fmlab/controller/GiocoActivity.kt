// FMLAB Emulator Android: lo schermo del gioco. Immagine dal motore nativo su una SurfaceView, tasti a schermo
// sopra (spariscono con un controller collegato), controller fisici uno per giocatore, menu col tasto Indietro.
package dev.fmlab.controller

import android.app.Activity
import android.app.AlertDialog
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
            override fun surfaceCreated(h: SurfaceHolder) { Motore.superficie(h.surface) }
            override fun surfaceChanged(h: SurfaceHolder, f: Int, w: Int, hh: Int) { Motore.superficie(h.surface) }
            override fun surfaceDestroyed(h: SurfaceHolder) { Motore.superficie(null) }
        })
        radice.addView(superficie, FrameLayout.LayoutParams(-1, -1))
        pad = PadView(this, trasparente = true, invia = { bit, giu -> tastiSchermo = if (giu) tastiSchermo or (1 shl bit) else tastiSchermo and (1 shl bit).inv(); invia(0) }) { menu() }
        pad.console(Emulatori.disposizione(nome), nome)
        radice.addView(pad, FrameLayout.LayoutParams(-1, -1))
        attesa = ProgressBar(this); radice.addView(attesa, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        etichetta = TextView(this).apply { setTextColor(Color.WHITE); textSize = 12f; setBackgroundColor(Color.argb(140, 0, 0, 0)); setPadding(12, 6, 12, 6); visibility = View.GONE }
        radice.addView(etichetta, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END))
        setContentView(radice)
        schermoIntero()
        (getSystemService(Context.INPUT_SERVICE) as InputManager).registerInputDeviceListener(this, null)
        aggiornaController()
        applicaImmagine()
        // il motore apre il gioco su un filo suo (fino a qualche secondo per i dischi grandi)
        Thread {
            val core = Emulatori.libreria(this, nome).path
            val err = Motore.avvia(core, gioco.path, Archivio.bios.path, Archivio.salvataggi.path, Emulatori.opzioni(nome, prefs.getInt("qualita", 1)))
            runOnUiThread {
                attesa.visibility = View.GONE
                if (err != null) {
                    AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(gioco.nameWithoutExtension)
                        .setMessage(getString(R.string.gioco_non_parte, err)).setPositiveButton("OK") { _, _ -> finish() }.setCancelable(false).show()
                } else { avviato = true; if (prefs.getBoolean("fps", false)) mostraFps() }
            }
        }.start()
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
    override fun onDestroy() {
        (getSystemService(Context.INPUT_SERVICE) as InputManager).unregisterInputDeviceListener(this)
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
            getString(if (veloce) R.string.veloce_spento else R.string.veloce_acceso), getString(R.string.immagine), getString(R.string.esci_gioco))
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert).setTitle(gioco.nameWithoutExtension).setItems(voci) { _, i ->
            when (i) {
                1 -> Toast.makeText(this, if (Motore.salvaStato(stato.path)) R.string.stato_salvato else R.string.stato_non_riuscito, Toast.LENGTH_SHORT).show()
                2 -> Toast.makeText(this, if (stato.exists() && Motore.caricaStato(stato.path)) R.string.stato_caricato else R.string.stato_non_riuscito, Toast.LENGTH_SHORT).show()
                3 -> { veloce = !veloce; Motore.veloce(veloce, prefs.getBoolean("muto", true)) }
                4 -> { scegliImmagine(); return@setItems }
                5 -> { finish(); return@setItems }
            }
            Motore.pausa(false)
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
    private fun invia(p: Int) { Motore.tasti(p, tastiController[p] or (if (p == 0) tastiSchermo else 0)) }

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
        val psp = nome == "ppsspp" || nome.startsWith("mupen") || nome == "citra" || nome == "dolphin" || nome == "flycast"
        var t = tastiController[p] and ((1 shl Tasto.SU) or (1 shl Tasto.GIU) or (1 shl Tasto.SINISTRA) or (1 shl Tasto.DESTRA) or (1 shl Tasto.L2) or (1 shl Tasto.R2)).inv()
        val soglia = if (psp) 2f else 0.5f
        if (hy < -0.5f || y < -soglia) t = t or (1 shl Tasto.SU); if (hy > 0.5f || y > soglia) t = t or (1 shl Tasto.GIU)
        if (hx < -0.5f || x < -soglia) t = t or (1 shl Tasto.SINISTRA); if (hx > 0.5f || x > soglia) t = t or (1 shl Tasto.DESTRA)
        if (e.getAxisValue(MotionEvent.AXIS_LTRIGGER) > 0.5f || e.getAxisValue(MotionEvent.AXIS_BRAKE) > 0.5f) t = t or (1 shl Tasto.L2)
        if (e.getAxisValue(MotionEvent.AXIS_RTRIGGER) > 0.5f || e.getAxisValue(MotionEvent.AXIS_GAS) > 0.5f) t = t or (1 shl Tasto.R2)
        tastiController[p] = t; invia(p); return true
    }
}
