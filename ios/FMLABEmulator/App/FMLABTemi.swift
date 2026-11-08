// FMLAB Emulator: aspetto dei comandi a schermo (temi) e la pagina per sceglierlo con l'anteprima.
import SwiftUI
import UIKit

struct FMLABTemaComandi {
    let id: String
    let nome: String
    let spiega: String
    let fondoBase: UIColor        // tasti e croce (l'opacità la decide l'utente)
    let premuto: UIColor
    let coloreBordo: UIColor
    let bordo: CGFloat
    let freccia: UIColor
    let quadrati: Bool
    let colorati: Bool            // tasti con i colori della console (SNES, PlayStation…)

    func fondo(_ alfa: CGFloat) -> UIColor { fondoBase.withAlphaComponent(fondoBase.cgColor.alpha * alfa) }

    /// Colore delle lettere/simboli.
    func testo(_ t: FMLABTasto, core: String, ps: Bool) -> UIColor {
        if id == "contrasto" { return .black }
        if ps || core == "pcsx_rearmed" || core == "ppsspp" {      // ○ ✕ △ □ con i loro colori
            switch t {
            case .a: return UIColor(red: 1, green: 0.42, blue: 0.45, alpha: 1)
            case .b: return UIColor(red: 0.5, green: 0.68, blue: 1, alpha: 1)
            case .x: return UIColor(red: 0.35, green: 0.85, blue: 0.7, alpha: 1)
            case .y: return UIColor(red: 0.95, green: 0.55, blue: 0.85, alpha: 1)
            default: break
            }
        }
        return id == "minimale" ? UIColor(white: 1, alpha: 0.85) : .white
    }
    /// Fondo del singolo tasto per i temi "con i colori della console"; nil = fondo normale.
    func fondoTasto(_ t: FMLABTasto, core: String, alfa: CGFloat) -> UIColor? {
        guard colorati else { return nil }
        let c: UIColor?
        switch (core, t) {
        case ("bsnes", .a): c = UIColor(red: 0.85, green: 0.2, blue: 0.22, alpha: 1)
        case ("bsnes", .b): c = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        case ("bsnes", .x): c = UIColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1)
        case ("bsnes", .y): c = UIColor(red: 0.15, green: 0.65, blue: 0.3, alpha: 1)
        case ("fceumm", .a), ("fceumm", .b), ("gambatte", .a), ("gambatte", .b): c = UIColor(red: 0.62, green: 0.1, blue: 0.2, alpha: 1)
        case ("mgba", .a), ("mgba", .b), ("desmume", .a), ("desmume", .b), ("desmume", .x), ("desmume", .y): c = UIColor(red: 0.32, green: 0.3, blue: 0.5, alpha: 1)
        default: c = nil
        }
        return c?.withAlphaComponent(max(0.35, alfa))
    }

    static let tutti: [FMLABTemaComandi] = [
        .init(id: "fmlab", nome: "FMLAB", spiega: "Dark grey, the button lights up red when pressed. Discreet, good on every game.",
              fondoBase: UIColor(white: 0.22, alpha: 1), premuto: UIColor(red: 0.85, green: 0.27, blue: 0.27, alpha: 1), coloreBordo: UIColor(white: 1, alpha: 0.15), bordo: 1, freccia: .white, quadrati: false, colorati: false),
        .init(id: "console", nome: "Console Colours", spiega: "The buttons have the colours of the real controller: red, yellow, blue and green on SNES, wine red on NES and Game Boy, purple on GBA and DS.",
              fondoBase: UIColor(white: 0.2, alpha: 1), premuto: .white, coloreBordo: UIColor(white: 1, alpha: 0.2), bordo: 1, freccia: .white, quadrati: false, colorati: true),
        .init(id: "vetro", nome: "Glass", spiega: "Almost see-through with a light edge: you see more of the game under your fingers.",
              fondoBase: UIColor(white: 1, alpha: 0.12), premuto: UIColor(white: 1, alpha: 0.55), coloreBordo: UIColor(white: 1, alpha: 0.55), bordo: 1.5, freccia: .white, quadrati: false, colorati: false),
        .init(id: "neon", nome: "Red Neon", spiega: "Black buttons with a bright red outline, in the style of the FMLAB logo.",
              fondoBase: UIColor(white: 0.03, alpha: 1), premuto: UIColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1), coloreBordo: UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1), bordo: 2, freccia: UIColor(red: 1, green: 0.35, blue: 0.35, alpha: 1), quadrati: false, colorati: false),
        .init(id: "minimale", nome: "Outline", spiega: "Only a thin outline, no fill: the most invisible, for those who know where the buttons are.",
              fondoBase: UIColor(white: 0, alpha: 0.05), premuto: UIColor(white: 1, alpha: 0.4), coloreBordo: UIColor(white: 1, alpha: 0.6), bordo: 1, freccia: UIColor(white: 1, alpha: 0.85), quadrati: false, colorati: false),
        .init(id: "arcade", nome: "Arcade", spiega: "Square buttons with rounded corners, like an arcade cabinet.",
              fondoBase: UIColor(white: 0.16, alpha: 1), premuto: UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1), coloreBordo: UIColor(white: 1, alpha: 0.25), bordo: 1.5, freccia: .white, quadrati: true, colorati: false),
        .init(id: "contrasto", nome: "High Contrast", spiega: "White buttons with black letters: the easiest to see, even in sunlight.",
              fondoBase: UIColor(white: 0.95, alpha: 1), premuto: UIColor(red: 0.85, green: 0.27, blue: 0.27, alpha: 1), coloreBordo: UIColor(white: 0, alpha: 0.3), bordo: 1, freccia: .black, quadrati: false, colorati: false),
    ]
    static var attuale: FMLABTemaComandi {
        let id = UserDefaults.standard.string(forKey: "FMLAB.comandi.tema") ?? "fmlab"
        return tutti.first { $0.id == id } ?? tutti[0]
    }
}

/// Pagina "Aspetto dei comandi": i temi con l'anteprima vera dei tasti, misura e trasparenza.
struct FMLABComandiView: View {
    @AppStorage("FMLAB.comandi.tema") private var tema = "fmlab"
    @AppStorage("FMLAB.comandi.scala") private var scala = 1.0
    @AppStorage("FMLAB.comandi.opacita") private var opacita = 0.9
    @AppStorage("FMLAB.comandi.vibra") private var vibra = true
    @State private var console = "bsnes"
    var body: some View {
        List {
            Section {
                Picker("Preview", selection: $console) { Text("SNES").tag("bsnes"); Text("PlayStation").tag("ppsspp"); Text("NES").tag("fceumm"); Text("GBA").tag("mgba") }.pickerStyle(.segmented)
            } footer: { Text("The preview shows the buttons of the chosen console with the theme you tap below.") }
            Section {
                ForEach(FMLABTemaComandi.tutti, id: \.id) { t in
                    Button { tema = t.id } label: {
                        HStack(spacing: 14) {
                            FMLABAnteprimaTasti(tema: t, core: console, alfa: opacita).frame(width: 96, height: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LF(t.nome)).font(.body.weight(.semibold)).foregroundColor(.primary)
                                Text(LF(t.spiega)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                            if tema == t.id { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
                        }.padding(.vertical, 4)
                    }
                }
            } header: { Text("Theme") }
            Section {
                Picker("Size", selection: $scala) { Text("Small").tag(0.85); Text("Normal").tag(1.0); Text("Large").tag(1.2); Text("Extra Large").tag(1.4) }
                VStack(alignment: .leading) { Text("Opacity"); Slider(value: $opacita, in: 0.3...1) }
                Toggle("Vibration", isOn: $vibra)
            } footer: { Text("To move a button or make it bigger: in a game open the menu › Move Buttons, then drag and pinch. Positions are saved per console, in portrait and landscape.") }
        }
        .navigationTitle(LF("Controls Look"))
    }
}

/// Croce e quattro tasti disegnati come nel gioco, per l'anteprima.
struct FMLABAnteprimaTasti: View {
    let tema: FMLABTemaComandi
    let core: String
    let alfa: Double
    var body: some View {
        GeometryReader { g in
            let h = g.size.height, d = h * 0.36, ps = core == "ppsspp"
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.12).fill(Color(white: 0.08))
                // croce
                Path { p in
                    let c = CGPoint(x: h * 0.5, y: h * 0.5), l = h * 0.62, s = l / 3
                    p.addRoundedRect(in: CGRect(x: c.x - l / 2, y: c.y - s / 2, width: l, height: s), cornerSize: CGSize(width: 3, height: 3))
                    p.addRoundedRect(in: CGRect(x: c.x - s / 2, y: c.y - l / 2, width: s, height: l), cornerSize: CGSize(width: 3, height: 3))
                }.fill(Color(tema.fondo(CGFloat(alfa))))
                ForEach(Array([(FMLABTasto.x, 0.0, -1.0), (.a, 1.0, 0.0), (.b, 0.0, 1.0), (.y, -1.0, 0.0)].enumerated()), id: \.offset) { _, v in
                    let (t, dx, dy) = v
                    let nomi: [FMLABTasto: String] = ps ? [.a: "○", .b: "✕", .x: "△", .y: "□"] : [.a: "A", .b: "B", .x: "X", .y: "Y"]
                    let fondo = tema.fondoTasto(t, core: core, alfa: CGFloat(alfa)) ?? tema.fondo(CGFloat(alfa))
                    ZStack {
                        (tema.quadrati ? FMLABForma(RoundedRectangle(cornerRadius: d * 0.28)) : FMLABForma(Circle())).fill(Color(fondo))
                        (tema.quadrati ? FMLABForma(RoundedRectangle(cornerRadius: d * 0.28)) : FMLABForma(Circle())).stroke(Color(tema.coloreBordo), lineWidth: tema.bordo)
                        Text(nomi[t] ?? "").font(.system(size: d * 0.5, weight: .bold)).foregroundColor(Color(tema.testo(t, core: core, ps: ps)))
                    }
                    .frame(width: d, height: d)
                    .position(x: g.size.width - h * 0.5 + CGFloat(dx) * d * 0.95, y: h * 0.5 + CGFloat(dy) * d * 0.95)
                }
            }
        }
    }
}

/// Forma qualunque (cerchio o quadrato) dentro lo stesso codice.
struct FMLABForma: Shape {
    private let disegna: (CGRect) -> Path
    init<S: Shape>(_ s: S) { disegna = { s.path(in: $0) } }
    func path(in rect: CGRect) -> Path { disegna(rect) }
}
