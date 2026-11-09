// FMLAB Controller: lo schermo dei tasti. Multi-tocco, croce a 8 direzioni, tasti giusti per la console del gioco.
package dev.fmlab.controller

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Toast
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.min

class PadActivity : Activity() {
    private lateinit var pad: PadView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        pad = PadView(this) { chiediUscita() }
        setContentView(pad)
        schermoIntero()
        Collegamento.ultimo?.let { pad.imposta(it) }
    }
    @Suppress("DEPRECATION")
    private fun schermoIntero() {
        if (Build.VERSION.SDK_INT >= 30) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { it.hide(WindowInsets.Type.systemBars()); it.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE }
        } else {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }
    override fun onResume() {
        super.onResume()
        Collegamento.ascolta = { e ->
            when (e) {
                is Evento.Collegato -> pad.imposta(e)
                is Evento.Pieno -> finish()
                is Evento.Perso -> { Toast.makeText(this, R.string.perso, Toast.LENGTH_LONG).show(); finish() }
            }
        }
        if (Collegamento.ultimo == null) finish()
    }
    override fun onPause() { super.onPause(); Collegamento.rilasciaTutto() }
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { chiediUscita() }

    private fun chiediUscita() {
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(pad.intestazione).setMessage(R.string.esci_domanda)
            .setPositiveButton(R.string.esci) { _, _ -> Collegamento.chiudi(); finish() }
            .setNegativeButton(R.string.annulla, null).show()
    }
}

/** I tasti disegnati a mano: niente ritardi, niente librerie. */
class PadView(context: Context, private val trasparente: Boolean = false, private val invia: (Int, Boolean) -> Unit = { b, g -> Collegamento.tasto(b, g) }, private val menu: () -> Unit) : View(context) {
    private class Bottone(val bit: Int, var etichetta: String, val rett: RectF = RectF(), var tondo: Boolean = true)

    var intestazione = ""; private set
    private var disposizione = 2
    private var core = ""
    private val tasti = mutableListOf<Bottone>()
    private val centroCroce = FloatArray(2); private var raggioCroce = 0f
    private val rettMenu = RectF()
    private val premutiPerDito = HashMap<Int, Set<Int>>()
    private var premuti = emptySet<Int>()
    private val d = resources.displayMetrics.density

    private val sfondo = Paint().apply { color = Color.rgb(16, 12, 12) }
    private val pieno = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(70, 255, 255, 255) }
    private val acceso = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(220, 50, 50) }
    private val bordo = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 2 * d; color = Color.argb(140, 230, 60, 60) }
    private val scritta = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textAlign = Paint.Align.CENTER; isFakeBoldText = true }
    private val testa = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.LTGRAY; textAlign = Paint.Align.CENTER; textSize = 15 * d }

    init { isHapticFeedbackEnabled = true }

    /** Nel gioco: console e tasti senza collegamento di rete. */
    fun console(disp: Int, nomeCore: String) { disposizione = disp; core = nomeCore; costruisci(); invalidate() }
    var nascosto = false; set(v) { field = v; invalidate() }
    /** Tocco fuori dai tasti (schermo touch di DS e 3DS): x, y in pixel della vista, giù/su. */
    var toccoLibero: ((Float, Float, Boolean) -> Unit)? = null
    private var ditoLibero = -1
    /** Gioco sulla TV: il telefono è il controller (fondo scuro, e per DS/3DS un tappetino per toccare lo schermo di sotto). */
    var suTV = false; set(v) { field = v; costruisci(); invalidate() }
    val tappetino = RectF()

    fun imposta(e: Evento.Collegato) {
        intestazione = context.getString(R.string.giocatore, e.giocatore) + " · " + e.titolo.ifEmpty { context.getString(R.string.attesa_gioco) }
        if (e.disposizione != disposizione || e.core != core) { disposizione = e.disposizione; core = e.core; requestLayout() }
        costruisci(); invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) { costruisci() }

    /** Posizioni: croce a sinistra, tasti a destra, spalle in alto, Select/Start al centro (come un controller vero). */
    private fun costruisci() {
        val w = width.toFloat(); val h = height.toFloat(); if (w <= 0 || h <= 0) return
        tasti.clear()
        val ps = core == "pcsx_rearmed" || core == "ppsspp"
        val verticale = h > w
        // verticale: tasti nella parte bassa (il gioco sta in alto); orizzontale: ai lati, il gioco in mezzo
        raggioCroce = if (verticale) min(w * 0.17f, h * 0.085f) else min(h * 0.24f, w * 0.13f)
        val yTasti = if (verticale) h * 0.74f else h * 0.6f
        centroCroce[0] = if (verticale) w * 0.24f else w * 0.13f; centroCroce[1] = yTasti
        val r = if (verticale) min(w * 0.075f, h * 0.036f) else min(h * 0.085f, w * 0.048f)
        val cx = if (verticale) w * 0.76f else w * 0.87f; val cy = yTasti; val passo = r * 2.15f
        fun tondo(bit: Int, nome: String, x: Float, y: Float) = tasti.add(Bottone(bit, nome, RectF(x - r, y - r, x + r, y + r)))
        when (disposizione) {
            0 -> { tondo(Tasto.B, "B", cx - passo * 0.55f, cy + passo * 0.35f); tondo(Tasto.A, "A", cx + passo * 0.55f, cy - passo * 0.35f) }
            1 -> { tondo(Tasto.B, "B", cx - passo * 0.55f, cy + passo * 0.35f); tondo(Tasto.A, "A", cx + passo * 0.55f, cy - passo * 0.35f) }
            else -> {
                tondo(Tasto.X, if (ps) "△" else "X", cx, cy - passo); tondo(Tasto.B, if (ps) "✕" else "B", cx, cy + passo)
                tondo(Tasto.Y, if (ps) "□" else "Y", cx - passo, cy); tondo(Tasto.A, if (ps) "○" else "A", cx + passo, cy)
            }
        }
        val m = 16 * d
        val sw = if (verticale) w * 0.22f else w * 0.13f; val sh = if (verticale) 46 * d else minOf(h * 0.11f, 52 * d)
        val ySpalle = if (verticale) yTasti - raggioCroce - sh - 26 * d else m
        fun spalla(bit: Int, nome: String, x: Float) = tasti.add(Bottone(bit, nome, RectF(x, ySpalle, x + sw, ySpalle + sh), false))
        if (disposizione >= 1) { spalla(Tasto.L, if (ps) "L1" else "L", m); spalla(Tasto.R, if (ps) "R1" else "R", w - m - sw) }
        if (disposizione >= 3) { spalla(Tasto.L2, "L2", m + sw + m); spalla(Tasto.R2, "R2", w - 2 * m - 2 * sw) }
        // tappetino per lo schermo da toccare quando il gioco è sulla TV: lo spazio libero tra i tasti
        if (verticale) tappetino.set(w * 0.08f, 70 * d, w * 0.92f, ySpalle - 16 * d) else tappetino.set(w * 0.28f, 60 * d, w * 0.72f, h - 70 * d)
        val bw = 84 * d; val bh = 38 * d
        if (verticale) {   // in basso al centro, sotto i tasti
            val by = h - m - bh
            tasti.add(Bottone(Tasto.SELECT, "SELECT", RectF(w / 2 - bw - 8 * d, by, w / 2 - 8 * d, by + bh), false))
            tasti.add(Bottone(Tasto.START, "START", RectF(w / 2 + 8 * d, by, w / 2 + bw + 8 * d, by + bh), false))
            rettMenu.set(w / 2 - 28 * d, yTasti - 20 * d, w / 2 + 28 * d, yTasti + 20 * d)
        } else {           // agli angoli in basso, fuori dal gioco
            val by = h - m - bh
            tasti.add(Bottone(Tasto.SELECT, "SELECT", RectF(m, by, m + bw, by + bh), false))
            tasti.add(Bottone(Tasto.START, "START", RectF(w - m - bw, by, w - m, by + bh), false))
            rettMenu.set(w - m - 56 * d, m + sh + 14 * d, w - m, m + sh + 54 * d)
        }
    }

    override fun onDraw(c: Canvas) {
        if (nascosto) { c.drawRoundRect(rettMenu, 12 * d, 12 * d, pieno); scritta.textSize = 22 * d; c.drawText("≡", rettMenu.centerX(), rettMenu.centerY() - (scritta.descent() + scritta.ascent()) / 2, scritta); return }
        if (!trasparente || suTV) {
            c.drawRect(0f, 0f, width.toFloat(), height.toFloat(), sfondo)
            if (!trasparente) c.drawText(intestazione, width / 2f, 30 * d + testa.textSize, testa)
        }
        if (suTV) {
            c.drawText(context.getString(R.string.gioco_sulla_tv), width / 2f, 30 * d + testa.textSize, testa)
            if (toccoLibero != null) { c.drawRoundRect(tappetino, 18 * d, 18 * d, pieno); c.drawRoundRect(tappetino, 18 * d, 18 * d, bordo)
                c.drawText(context.getString(R.string.tappetino), tappetino.centerX(), tappetino.centerY(), testa) }
        }
        // croce
        val x = centroCroce[0]; val y = centroCroce[1]; val a = raggioCroce; val b = a * 0.36f
        for ((dir, rr) in listOf(Tasto.SU to RectF(x - b, y - a, x + b, y - b), Tasto.GIU to RectF(x - b, y + b, x + b, y + a),
                                 Tasto.SINISTRA to RectF(x - a, y - b, x - b, y + b), Tasto.DESTRA to RectF(x + b, y - b, x + a, y + b))) {
            c.drawRoundRect(rr, 8 * d, 8 * d, if (dir in premuti) acceso else pieno); c.drawRoundRect(rr, 8 * d, 8 * d, bordo)
        }
        c.drawRect(x - b, y - b, x + b, y + b, pieno)
        for (t in tasti) {
            val p = if (t.bit in premuti) acceso else pieno
            if (t.tondo) { c.drawOval(t.rett, p); c.drawOval(t.rett, bordo) } else { c.drawRoundRect(t.rett, 12 * d, 12 * d, p); c.drawRoundRect(t.rett, 12 * d, 12 * d, bordo) }
            scritta.textSize = if (t.tondo) t.rett.height() * 0.42f else minOf(t.rett.height() * 0.38f, t.rett.width() / (t.etichetta.length * 0.62f + 0.6f))
            c.drawText(t.etichetta, t.rett.centerX(), t.rett.centerY() - (scritta.descent() + scritta.ascent()) / 2, scritta)
        }
        c.drawRoundRect(rettMenu, 12 * d, 12 * d, pieno)
        scritta.textSize = 22 * d; c.drawText("≡", rettMenu.centerX(), rettMenu.centerY() - (scritta.descent() + scritta.ascent()) / 2, scritta)
    }

    /** Cosa preme un dito in quel punto (la croce va anche in diagonale). */
    private fun sotto(px: Float, py: Float): Set<Int> {
        val dx = px - centroCroce[0]; val dy = py - centroCroce[1]; val dist = hypot(dx, dy)
        if (dist < raggioCroce * 1.5f && px < width * 0.45f) {
            if (dist < raggioCroce * 0.22f) return emptySet()
            val ang = Math.toDegrees(atan2(dy.toDouble(), dx.toDouble()))   // 0 = destra, 90 = giù
            val s = mutableSetOf<Int>()
            if (ang in -67.5..67.5) s.add(Tasto.DESTRA)
            if (ang > 22.5 && ang < 157.5) s.add(Tasto.GIU)
            if (ang > 112.5 || ang < -112.5) s.add(Tasto.SINISTRA)
            if (ang < -22.5 && ang > -157.5) s.add(Tasto.SU)
            return s
        }
        var migliore: Bottone? = null; var dm = Float.MAX_VALUE
        for (t in tasti) {
            val r = RectF(t.rett).apply { inset(-t.rett.width() * 0.25f, -t.rett.height() * 0.25f) }
            if (r.contains(px, py)) { val dd = hypot(px - t.rett.centerX(), py - t.rett.centerY()); if (dd < dm) { dm = dd; migliore = t } }
        }
        return migliore?.let { setOf(it.bit) } ?: emptySet()
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        val i = e.actionIndex
        if (nascosto) { if (e.actionMasked == MotionEvent.ACTION_DOWN && rettMenu.contains(e.getX(i), e.getY(i))) menu(); return true }
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                if (rettMenu.contains(e.getX(i), e.getY(i))) { menu(); return true }
                val s = sotto(e.getX(i), e.getY(i))
                if (s.isEmpty() && toccoLibero != null && ditoLibero < 0) { ditoLibero = e.getPointerId(i); toccoLibero?.invoke(e.getX(i), e.getY(i), true) }
                else premutiPerDito[e.getPointerId(i)] = s
            }
            MotionEvent.ACTION_MOVE -> for (k in 0 until e.pointerCount) {
                val id = e.getPointerId(k)
                if (id == ditoLibero) toccoLibero?.invoke(e.getX(k), e.getY(k), true)
                else premutiPerDito[id]?.let { premutiPerDito[id] = sotto(e.getX(k), e.getY(k)) }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                val id = e.getPointerId(i)
                if (id == ditoLibero) { toccoLibero?.invoke(e.getX(i), e.getY(i), false); ditoLibero = -1 } else premutiPerDito.remove(id)
            }
            MotionEvent.ACTION_CANCEL -> { premutiPerDito.clear(); if (ditoLibero >= 0) { toccoLibero?.invoke(0f, 0f, false); ditoLibero = -1 } }
        }
        val ora = premutiPerDito.values.flatten().toSet()
        if (ora != premuti) {
            for (b in ora - premuti) invia(b, true)
            for (b in premuti - ora) invia(b, false)
            if ((ora - premuti).isNotEmpty()) performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            premuti = ora; invalidate()
        }
        return true
    }
}
