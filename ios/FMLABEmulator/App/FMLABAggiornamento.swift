// FMLAB Emulator: aggiornamenti dell'app.
// Ogni versione esce su GitHub (release "v<numero>" e "ultima"). L'app guarda VERSIONE.txt di "ultima"; se c'è una
// versione più nuova mostra cosa cambia e un tasto Aggiorna, che passa l'IPA a LiveContainer con il suo link
// livecontainer://install?url=… (LiveContainer 3.3+): l'app si aggiorna sopra quella vecchia, i dati restano.
// Fuori da LiveContainer (SideStore, AltStore) il link dell'IPA si copia e si apre la pagina della versione.
import SwiftUI
import UIKit

final class FMLABAggiornamento: ObservableObject {
    static let shared = FMLABAggiornamento()
    static let repo = "cipherdesk007-max/emulator-ios-andorid"
    static let pagina = "https://github.com/\(repo)"
    static var attuale: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    static func ipa(_ v: String) -> String { "\(pagina)/releases/download/v\(v)/FMLAB-Emulator.ipa" }
    static let sorgente = "\(pagina)/releases/download/ultima/apps.json"
    /// Sempre l'ultima versione (lo stesso link dell'installazione).
    static let linkUltima = "\(pagina)/releases/download/ultima/FMLAB-Emulator.ipa"

    @Published private(set) var nuova: String?
    @Published private(set) var note: String?
    @Published private(set) var controllando = false
    @Published private(set) var ultimoControllo: Date? = UserDefaults.standard.object(forKey: "FMLAB.app.ultimoControllo") as? Date

    /// `a` è più nuova di `b` (numeri separati da punti: 0.10.0 > 0.9.3).
    static func piuNuova(_ a: String, di b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) { let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0; if p != q { return p > q } }
        return false
    }

    /// Al più ogni 3 ore, se non si forza (tasto "Controlla adesso").
    func controlla(forza: Bool = false) {
        if !forza, let u = ultimoControllo, Date().timeIntervalSince(u) < 3 * 3600, nuova == nil { return }
        guard !controllando else { return }
        controllando = true
        var r = URLRequest(url: URL(string: "\(Self.pagina)/releases/download/ultima/VERSIONE.txt")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        r.setValue("FMLAB-Emulator", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: r) { d, risposta, _ in
            let v = (risposta as? HTTPURLResponse)?.statusCode == 200 ? d.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let valida = v.flatMap { $0.count < 16 && $0.allSatisfy({ $0.isNumber || $0 == "." }) ? $0 : nil }
            DispatchQueue.main.async {
                self.controllando = false
                guard let valida else { return }
                let ora = Date(); self.ultimoControllo = ora; UserDefaults.standard.set(ora, forKey: "FMLAB.app.ultimoControllo")
                if Self.piuNuova(valida, di: Self.attuale) { self.nuova = valida; self.leggiNote(valida) } else { self.nuova = nil; self.note = nil }
            }
        }.resume()
    }
    private func leggiNote(_ v: String) {
        var r = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/tags/v\(v)")!, timeoutInterval: 12)
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept"); r.setValue("FMLAB-Emulator", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: r) { d, _, _ in
            let corpo = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["body"] as? String
            DispatchQueue.main.async { self.note = corpo?.trimmingCharacters(in: .whitespacesAndNewlines) }
        }.resume()
    }

    /// Aggiorna: LiveContainer scarica e installa l'IPA sopra questa versione.
    func installa() {
        guard let v = nuova else { return }
        let ipa = Self.ipa(v)
        var c = URLComponents(); c.scheme = "livecontainer"; c.host = "install"; c.queryItems = [URLQueryItem(name: "url", value: ipa)]
        UIPasteboard.general.string = ipa
        guard let link = c.url else { return }
        UIApplication.shared.open(link) { ok in
            if !ok, let pagina = URL(string: "\(Self.pagina)/releases/tag/v\(v)") { UIApplication.shared.open(pagina) }
        }
    }
    /// Aggiunge la "sorgente" di FMLAB a LiveContainer: lì le versioni nuove compaiono anche nella scheda Sorgenti.
    func aggiungiSorgente() {
        var c = URLComponents(); c.scheme = "livecontainer"; c.host = "source"; c.queryItems = [URLQueryItem(name: "url", value: Self.sorgente)]
        if let u = c.url { UIApplication.shared.open(u) }
    }
}

/// Riquadro "È uscita la versione …", in cima a Giochi e a Impostazioni.
/// LiveContainer non installa mentre fa girare un'app (dice "Riavvia LiveContainer"): il modo sicuro è copiare il
/// link, chiudere l'app e incollarlo in LiveContainer › + › Installa dall'URL.
struct FMLABAvvisoVersione: View {
    @ObservedObject private var agg = FMLABAggiornamento.shared
    @State private var dettagli = false
    @State private var copiato = false
    var body: some View {
        if let v = agg.nuova {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(format: LF("FMLAB Emulator %@ is out"), v), systemImage: "arrow.down.app.fill").font(.headline).foregroundColor(.accentColor)
                    Text(String(format: LF("You have %@. Your games, saves and settings stay as they are."), FMLABAggiornamento.attuale)).font(.caption).foregroundColor(.secondary)
                    if let n = agg.note, !n.isEmpty {
                        Text(Self.testo(n)).font(.caption).lineLimit(dettagli ? nil : 5)
                        Button(dettagli ? LF("Less") : LF("What's new…")) { withAnimation { dettagli.toggle() } }.font(.caption.weight(.semibold)).buttonStyle(.borderless)
                    }
                }.padding(.vertical, 4)
                Button {
                    UIPasteboard.general.string = FMLABAggiornamento.linkUltima
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation { copiato = true }
                } label: { Label(copiato ? LF("Link Copied") : LF("Copy the Update Link"), systemImage: copiato ? "checkmark.circle.fill" : "doc.on.doc.fill").font(.body.weight(.semibold)) }
                if copiato {
                    Label("Close FMLAB Emulator: swipe it away from the open apps.", systemImage: "1.circle.fill").font(.callout)
                    Label("Open LiveContainer › + › Install from URL and paste.", systemImage: "2.circle.fill").font(.callout)
                    Label("Confirm the update: games and saves stay.", systemImage: "3.circle.fill").font(.callout)
                }
            } footer: { Text("LiveContainer cannot install while it is running an app (it asks to restart): that is why you copy the link and install from LiveContainer. The link is always the latest version. With SideStore or AltStore paste it there.") }
        }
    }
    /// Le note sono scritte in Markdown (come su GitHub): qui si mostrano formattate, senza asterischi.
    static func testo(_ md: String) -> AttributedString {
        let pulito = md.replacingOccurrences(of: "\n  ", with: " ").replacingOccurrences(of: "\n    ", with: " ")
        return (try? AttributedString(markdown: pulito, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(pulito)
    }
}
