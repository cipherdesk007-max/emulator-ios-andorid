// FMLAB Emulator: porta qui giochi e salvataggi da FMLAB Linux (o da un'altra copia di FMLAB Emulator).
// Le due app non vedono l'una i file dell'altra: si sceglie dall'app File la cartella "Giochi" di FMLAB Linux
// (o la cartella di Esporta copia) e si copia tutto: giochi, Salvataggi (con Riprendi, stati e copie datate),
// BIOS, Copertine. L'originale non si tocca: dopo il controllo si può cancellare da FMLAB Linux.
import Foundation
import SwiftUI
import UIKit

enum FMLABTrasloco {
    struct Esito {
        var giochi = 0, salvataggi = 0, altri = 0, uguali = 0, piuNuoviQui = 0, inCloud = 0
        var byte: Int64 = 0
        var errori: [String] = []
        var vuoto: Bool { giochi + salvataggi + altri + uguali + piuNuoviQui == 0 }
    }
    private struct DaCopiare { let da: URL; let rel: String; let peso: Int64; let data: Date }

    /// Sceglie la radice giusta: la cartella Giochi, oppure Documents che la contiene, oppure una copia esportata.
    static func radice(_ u: URL) -> URL {
        let fm = FileManager.default
        for c in ["Giochi", "Documents/Giochi"] {
            let g = u.appendingPathComponent(c, isDirectory: true)
            var dir: ObjCBool = false
            if fm.fileExists(atPath: g.path, isDirectory: &dir), dir.boolValue { return g }
        }
        return u
    }

    /// Copia in sottofondo. `avanza(frazione, nome del file)` e `fatto` arrivano sul filo principale.
    static func importa(da scelta: URL, avanza: @escaping (Double, String) -> Void, fatto: @escaping (Esito) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accesso = scelta.startAccessingSecurityScopedResource()
            defer { if accesso { scelta.stopAccessingSecurityScopedResource() } }
            let fm = FileManager.default, base = FMLABEmulatore.cartellaGiochi(), da = radice(scelta)
            var esito = Esito(), lista: [DaCopiare] = []
            let chiavi: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
            // 1. elenco: tutto tranne file nascosti, il LEGGIMI e le cartelle temporanee delle copie
            if let giro = fm.enumerator(at: da, includingPropertiesForKeys: chiavi, options: [.skipsPackageDescendants]) {
                for case let f as URL in giro {
                    let nome = f.lastPathComponent
                    if nome.hasPrefix(".in-corso") { giro.skipDescendants(); continue }
                    if nome.hasSuffix(".icloud") { esito.inCloud += 1; continue }        // in iCloud, non scaricato
                    guard let v = try? f.resourceValues(forKeys: Set(chiavi)), v.isRegularFile == true, v.isHidden != true,
                          !nome.hasPrefix("."), !nome.hasPrefix("LEGGIMI") else { continue }
                    let rel = String(f.standardizedFileURL.path.dropFirst(da.standardizedFileURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if rel == "impostazioni.json" { continue }
                    lista.append(DaCopiare(da: f, rel: rel, peso: Int64(v.fileSize ?? 0), data: v.contentModificationDate ?? .distantPast))
                }
            }
            // 2. cosa serve davvero: un file uguale (stessa misura e data) non si ricopia; uno più nuovo qui non si sovrascrive
            var scelti: [DaCopiare] = []
            for c in lista {
                let a = base.appendingPathComponent(c.rel)
                if let v = try? a.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
                    let dataQui = v.contentModificationDate ?? .distantPast
                    if Int64(v.fileSize ?? -1) == c.peso && abs(dataQui.timeIntervalSince(c.data)) < 2 { esito.uguali += 1; continue }
                    if dataQui > c.data.addingTimeInterval(2) { esito.piuNuoviQui += 1; continue }
                }
                scelti.append(c)
            }
            // 3. spazio: meglio fermarsi prima che a metà
            let serve = scelti.reduce(Int64(0)) { $0 + $1.peso }
            let libero = (try? base.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? Int64.max
            if serve > libero - 200_000_000 {
                esito.errori.append(String(format: LF("Not enough space: %@ needed, %@ free."), ByteCountFormatter.string(fromByteCount: serve, countStyle: .file), ByteCountFormatter.string(fromByteCount: libero, countStyle: .file)))
                DispatchQueue.main.async { fatto(esito) }; return
            }
            // 4. copia: prima in un file temporaneo accanto, poi al posto giusto (mai un file a metà)
            var fatti: Int64 = 0
            for c in scelti {
                DispatchQueue.main.async { avanza(serve > 0 ? Double(fatti) / Double(serve) : 1, c.rel) }
                let a = base.appendingPathComponent(c.rel), tmp = a.deletingLastPathComponent().appendingPathComponent(".in-arrivo-" + a.lastPathComponent)
                do {
                    try fm.createDirectory(at: a.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.removeItem(at: tmp)
                    try fm.copyItem(at: c.da, to: tmp)
                    try? fm.setAttributes([.modificationDate: c.data], ofItemAtPath: tmp.path)   // la data conta per Riprendi
                    if fm.fileExists(atPath: a.path) { _ = try fm.replaceItemAt(a, withItemAt: tmp) } else { try fm.moveItem(at: tmp, to: a) }
                    fatti += c.peso; esito.byte += c.peso
                    let primo = c.rel.split(separator: "/").first.map(String.init) ?? ""
                    if primo == "Salvataggi" { esito.salvataggi += 1 } else if primo == "BIOS" || primo == "Copertine" { esito.altri += 1 } else { esito.giochi += 1 }
                } catch {
                    try? fm.removeItem(at: tmp)
                    esito.errori.append(c.rel + ": " + error.localizedDescription)
                }
            }
            // 5. impostazioni dei comandi, se la cartella scelta è una copia esportata
            let imp = scelta.appendingPathComponent("impostazioni.json")
            if let d = try? Data(contentsOf: imp), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let v = j["impostazioni"] as? [String: Any] {
                for k in FMLABCopia.chiavi { if let x = v[k] { UserDefaults.standard.set(x, forKey: k) } }
            }
            DispatchQueue.main.async { avanza(1, ""); fatto(esito) }
        }
    }
}

/// Scheda "Porta qui da FMLAB Linux": spiega dove trovare la cartella, copia e dice cosa ha fatto.
struct FMLABTraslocoView: View {
    var chiudi: () -> Void
    @State private var frazione: Double?
    @State private var file = ""
    @State private var esito: FMLABTrasloco.Esito?
    var body: some View {
        List {
            Section {
                Label("In FMLAB Linux close the game you were playing (that is when the last save is written).", systemImage: "1.circle.fill")
                Label("Tap Choose Folder and open: On My iPhone › LiveContainer › Data › Application › (the FMLAB Linux folder) › Documents › Giochi. If you installed FMLAB Linux with SideStore: On My iPhone › FMLAB Linux › Giochi.", systemImage: "2.circle.fill")
                Label("Everything is copied: games, saves with Resume and states, save backups, BIOS, covers. FMLAB Linux is not touched.", systemImage: "3.circle.fill")
            } header: { Text("From FMLAB Linux") } footer: {
                Text("A folder exported with Export Backup works too. Game folders you linked in FMLAB Linux (iCloud, On My iPhone) are not copied: link them again here with Choose Games Folder. A file that is newer here is never overwritten.")
            }
            if let f = frazione, esito == nil {
                Section {
                    ProgressView(value: f)
                    Text(file).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            } else {
                Section {
                    Button { FMLABSceltaFile.apri(cartella: true) { u in guard let u = u.first else { return }; avvia(u) } } label: {
                        Label("Choose Folder…", systemImage: "folder.badge.plus").font(.headline)
                    }
                }
            }
            if let e = esito {
                Section {
                    if e.vuoto && e.errori.isEmpty { Label("No games or saves in that folder: choose the Giochi folder of FMLAB Linux.", systemImage: "questionmark.folder").foregroundColor(.orange) }
                    if e.giochi > 0 { Label(String(format: LF("%ld games copied"), e.giochi), systemImage: "gamecontroller") }
                    if e.salvataggi > 0 { Label(String(format: LF("%ld save files copied"), e.salvataggi), systemImage: "externaldrive.badge.checkmark") }
                    if e.altri > 0 { Label(String(format: LF("%ld BIOS and cover files copied"), e.altri), systemImage: "photo.on.rectangle") }
                    if e.uguali > 0 { Label(String(format: LF("%ld files already here and identical"), e.uguali), systemImage: "equal.circle") }
                    if e.piuNuoviQui > 0 { Label(String(format: LF("%ld files kept: the copy here is newer"), e.piuNuoviQui), systemImage: "clock.arrow.circlepath") }
                    if e.inCloud > 0 { Label(String(format: LF("%ld files are in iCloud and not downloaded: open them in Files first, then repeat"), e.inCloud), systemImage: "icloud.and.arrow.down").foregroundColor(.orange) }
                    ForEach(e.errori.prefix(8), id: \.self) { Text($0).font(.caption).foregroundColor(.red) }
                } header: { Text("Done") } footer: {
                    Text("Open a game and check that your progress is there. Only then, if you want, delete the games from FMLAB Linux.")
                }
            }
        }
        .navigationTitle(LF("Bring Games from FMLAB Linux"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { chiudi() }.disabled(frazione != nil && esito == nil) } }
    }
    private func avvia(_ u: URL) {
        esito = nil; frazione = 0; file = ""
        UIApplication.shared.isIdleTimerDisabled = true
        FMLABTrasloco.importa(da: u, avanza: { f, n in frazione = f; file = n }) { e in
            esito = e; frazione = nil; UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
