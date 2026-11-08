// FMLAB Emulator: icone delle console disegnate da FMLAB (forme generiche delle macchine, niente marchi:
// i loghi ufficiali di Nintendo e Sony sono marchi registrati e non si copiano).
import SwiftUI

struct FMLABIconaConsole: View {
    let core: String
    var gbc = false
    var lato: CGFloat = 48
    var conSigla = true

    var body: some View {
        let c = fmlabSigla(core, gbc: gbc)
        ZStack {
            LinearGradient(colors: [c.1.opacity(0.95), c.1.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { g, s in disegna(g, s) }
                .padding(lato * (conSigla ? 0.14 : 0.12))
                .padding(.bottom, conSigla ? lato * 0.16 : 0)
            if conSigla {
                VStack { Spacer(); Text(c.0).font(.system(size: lato * 0.2, weight: .heavy, design: .rounded)).foregroundColor(.white.opacity(0.92)).padding(.bottom, lato * 0.05) }
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: lato * 0.22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: lato * 0.22, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // Tutte le forme in un quadrato 0…1, poi scalate.
    private func disegna(_ g: GraphicsContext, _ s: CGSize) {
        let k = min(s.width, s.height), ox = (s.width - k) / 2, oy = (s.height - k) / 2
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: ox + x * k, y: oy + y * k, width: w * k, height: h * k) }
        let bianco = GraphicsContext.Shading.color(.white), scuro = GraphicsContext.Shading.color(.black.opacity(0.45))
        func croce(_ cx: CGFloat, _ cy: CGFloat, _ l: CGFloat, _ colore: GraphicsContext.Shading) {
            g.fill(Path(roundedRect: r(cx - l / 2, cy - l / 6, l, l / 3), cornerRadius: l * 0.06 * k), with: colore)
            g.fill(Path(roundedRect: r(cx - l / 6, cy - l / 2, l / 3, l), cornerRadius: l * 0.06 * k), with: colore)
        }
        func punto(_ cx: CGFloat, _ cy: CGFloat, _ d: CGFloat, _ colore: GraphicsContext.Shading) { g.fill(Path(ellipseIn: r(cx - d / 2, cy - d / 2, d, d)), with: colore) }
        switch core {
        case "fceumm":      // controller rettangolare a due tasti
            g.fill(Path(roundedRect: r(0.02, 0.26, 0.96, 0.48), cornerRadius: 0.06 * k), with: bianco)
            croce(0.22, 0.5, 0.24, scuro)
            punto(0.66, 0.54, 0.13, .color(.red.opacity(0.8))); punto(0.83, 0.54, 0.13, .color(.red.opacity(0.8)))
            g.fill(Path(roundedRect: r(0.39, 0.52, 0.08, 0.04), cornerRadius: 0.01 * k), with: scuro); g.fill(Path(roundedRect: r(0.49, 0.52, 0.08, 0.04), cornerRadius: 0.01 * k), with: scuro)
        case "gambatte":    // portatile verticale
            g.fill(Path(roundedRect: r(0.2, 0.0, 0.6, 1.0), cornerRadius: 0.08 * k), with: bianco)
            g.fill(Path(roundedRect: r(0.28, 0.08, 0.44, 0.38), cornerRadius: 0.03 * k), with: gbc ? .color(Color(red: 0.55, green: 0.75, blue: 0.95)) : .color(Color(red: 0.6, green: 0.7, blue: 0.35)))
            croce(0.36, 0.68, 0.18, scuro); punto(0.6, 0.7, 0.09, scuro); punto(0.7, 0.64, 0.09, scuro)
        case "mgba":        // portatile orizzontale
            g.fill(Path(roundedRect: r(0.0, 0.24, 1.0, 0.52), cornerRadius: 0.2 * k), with: bianco)
            g.fill(Path(roundedRect: r(0.3, 0.32, 0.4, 0.3), cornerRadius: 0.02 * k), with: scuro)
            croce(0.15, 0.5, 0.15, scuro); punto(0.82, 0.46, 0.08, scuro); punto(0.9, 0.54, 0.08, scuro)
        case "bsnes":       // controller ad osso con quattro tasti
            g.fill(Path(roundedRect: r(0.0, 0.26, 1.0, 0.48), cornerRadius: 0.24 * k), with: bianco)
            croce(0.24, 0.5, 0.22, scuro)
            punto(0.76, 0.38, 0.1, .color(.purple.opacity(0.75))); punto(0.76, 0.62, 0.1, .color(.purple.opacity(0.75)))
            punto(0.65, 0.5, 0.1, .color(.purple.opacity(0.45))); punto(0.87, 0.5, 0.1, .color(.purple.opacity(0.45)))
        case "pcsx_rearmed": // disco
            punto(0.5, 0.5, 0.96, bianco)
            g.stroke(Path { p in p.addArc(center: CGPoint(x: ox + 0.5 * k, y: oy + 0.5 * k), radius: 0.33 * k, startAngle: .degrees(200), endAngle: .degrees(280), clockwise: false) }, with: .color(.gray.opacity(0.5)), lineWidth: 0.06 * k)
            punto(0.5, 0.5, 0.3, .color(Color(white: 0.75))); punto(0.5, 0.5, 0.13, scuro)
        case "ppsspp":      // portatile largo e sottile
            g.fill(Path(roundedRect: r(0.0, 0.3, 1.0, 0.4), cornerRadius: 0.2 * k), with: bianco)
            g.fill(Path(roundedRect: r(0.22, 0.35, 0.56, 0.3), cornerRadius: 0.02 * k), with: scuro)
            croce(0.1, 0.5, 0.12, scuro)
            punto(0.9, 0.43, 0.055, scuro); punto(0.9, 0.57, 0.055, scuro); punto(0.85, 0.5, 0.055, scuro); punto(0.95, 0.5, 0.055, scuro)
        case "desmume":     // due schermi a libro
            g.fill(Path(roundedRect: r(0.16, 0.0, 0.68, 0.46), cornerRadius: 0.06 * k), with: bianco)
            g.fill(Path(roundedRect: r(0.16, 0.54, 0.68, 0.46), cornerRadius: 0.06 * k), with: bianco)
            g.fill(Path(roundedRect: r(0.3, 0.07, 0.4, 0.32), cornerRadius: 0.02 * k), with: scuro)
            g.fill(Path(roundedRect: r(0.33, 0.6, 0.34, 0.26), cornerRadius: 0.02 * k), with: scuro)
            croce(0.235, 0.73, 0.1, scuro); punto(0.765, 0.73, 0.07, scuro)
        default:
            punto(0.5, 0.5, 0.6, bianco)
        }
    }
}
