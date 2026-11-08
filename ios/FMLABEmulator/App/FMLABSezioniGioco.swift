// FMLAB Emulator: le impostazioni dei giochi, spostate dalla lista dei giochi alla scheda Impostazioni
// (comandi, salvataggi, BIOS, grafica, TV, copie, console, dati del motore).
import SwiftUI
import CryptoKit

extension Notification.Name {
    /// Qualcosa è cambiato (copia ripristinata, giochi portati qui, dati del motore): la lista dei giochi si ricarica.
    static let fmlabRicarica = Notification.Name("FMLABRicarica")
}
func ricarica() { NotificationCenter.default.post(name: .fmlabRicarica, object: nil) }

/// Quanti giochi per console (per la lista delle console nelle impostazioni).
final class FMLABLibreria: ObservableObject {
    static let shared = FMLABLibreria()
    @Published private(set) var conteggio: [String: Int] = [:]
    @Published private(set) var totale = 0
    func aggiorna(_ g: [FMLABGioco]) { conteggio = Dictionary(grouping: g, by: { $0.core.nome }).mapValues(\.count); totale = g.count }
}

struct FMLABSezioniGioco: View {
    @ObservedObject private var libreria = FMLABLibreria.shared
    @State private var statoBIOS: [String: Bool] = [:]
    @State private var controllando = false
    @State private var errore: String?
    @State private var versioneDati = FMLABDati.versione
    @State private var schermoEsterno = FMLABGiocoController.nomeSchermoEsterno()
    @AppStorage("FMLAB.comandi.scala") private var scala = 1.0
    @AppStorage("FMLAB.comandi.opacita") private var opacita = 0.9
    @AppStorage("FMLAB.comandi.vibra") private var vibra = true
    @AppStorage("FMLAB.riprendi") private var riprendi = true
    @AppStorage("FMLAB.veloce.velocita") private var velocita = 3.0
    @AppStorage("FMLAB.comandi.sopra") private var sopra = true
    @AppStorage("FMLAB.grafica.qualita") private var qualita = (UserDefaults.standard.object(forKey: "FMLAB.grafica.migliorata") as? Bool ?? true) ? "migliorata" : "originale"
    @AppStorage("FMLAB.grafica.tvMassima") private var tvMassima = true
    @AppStorage("FMLAB.grafica.textureHD") private var textureHD = false
    @AppStorage("FMLAB.grafica.coloriLCD") private var coloriLCD = true
    @AppStorage("FMLAB.grafica.sciaLCD") private var sciaLCD = false
    @AppStorage("FMLAB.grafica.paletteGB") private var paletteGB = "auto"
    @AppStorage("FMLAB.grafica.paletteNES") private var paletteNES = "smooth-fbx"
    @AppStorage("FMLAB.veloce.suono") private var suonoVeloce = "muto"
    @AppStorage("FMLAB.grafica.filtro") private var filtro = "netti"
    @AppStorage("FMLAB.grafica.formato") private var formato = "originale"
    @AppStorage("FMLAB.grafica.gpu") private var gpu = true
    @AppStorage("FMLAB.suono.mischia") private var mischia = false
    @AppStorage("FMLAB.giochi.esterno") private var usaEsterno = true
    @AppStorage(FMLABCopertine.chiaveAttive) private var copertine = true
    @AppStorage("FMLAB.console.nascoste") private var nascosteTesto = ""
    private var nascoste: Set<String> { Set(nascosteTesto.split(separator: ",").map(String.init)) }

    var body: some View {
        Group {
            Section {
                Toggle(isOn: $sopra) { VStack(alignment: .leading, spacing: 3) { Text("Bigger Screen"); Text("The game takes all the space it can and the controls sit on top, see-through (above all on DS and in landscape).").font(.caption).foregroundColor(.secondary) } }
                NavigationLink { FMLABComandiView() } label: { HStack { Label("Controls Look", systemImage: "gamecontroller"); Spacer(); Text(LF(FMLABTemaComandi.attuale.nome)).foregroundColor(.secondary) } }
                Picker("Fast Forward Speed", selection: $velocita) { Text("2×").tag(2.0); Text("3×").tag(3.0); Text("4×").tag(4.0) }
                FMLABRigaScelta(titolo: "Sound in Fast Forward", opzioni: FMLABScelte.suonoVeloce, scelta: $suonoVeloce)
                Toggle(isOn: $copertine) { VStack(alignment: .leading, spacing: 3) { Text("Automatic Covers"); Text("Box art from the public libretro-thumbnails collection, found by file name (standard names like \"Super Mario World (USA)\").").font(.caption).foregroundColor(.secondary) } }
                Toggle(isOn: $mischia) { VStack(alignment: .leading, spacing: 3) { Text("Keep Music from Other Apps"); Text("Off: opening a game pauses Spotify and other music, like a real game does.").font(.caption).foregroundColor(.secondary) } }
                Toggle(isOn: $riprendi) { VStack(alignment: .leading, spacing: 3) { Text("Resume Where I Left Off"); Text("When you quit a game it is saved; next time you can continue from there.").font(.caption).foregroundColor(.secondary) } }
            } header: { Text("Controls and Saves") }
            if !FMLABDati.bios.isEmpty {
                Section {
                    ForEach(FMLABDati.bios, id: \.self) { b in
                        let nome = b["file"] ?? ""
                        HStack {
                            Image(systemName: statoBIOS[nome] == true ? "checkmark.seal.fill" : statoBIOS[nome] == false ? "exclamationmark.triangle.fill" : "circle.dashed")
                                .foregroundColor(statoBIOS[nome] == true ? .green : statoBIOS[nome] == false ? .orange : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nome).font(.callout.monospaced())
                                Text(b[UserDefaults.standard.string(forKey: "FMLAB.lingua") == "it" ? "it" : "en"] ?? "").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } header: { Text("BIOS (optional)") } footer: {
                    Text("Put your own BIOS files in Files › FMLAB Emulator › Giochi › BIOS. A green seal means the file is the right one (checked by its fingerprint); orange means a file with that name is there but it is different.")
                }
            }
            Section {
                FMLABRigaScelta(titolo: "Quality", opzioni: FMLABScelte.qualita, scelta: $qualita)
                Toggle(isOn: $tvMassima) { VStack(alignment: .leading, spacing: 3) { Text("Maximum on the TV"); Text("With Enhanced chosen, a game opened with the TV connected goes to Maximum: the TV is big and the iPhone only has to emulate.").font(.caption).foregroundColor(.secondary) } }
                FMLABRigaScelta(titolo: "Picture", opzioni: FMLABScelte.filtro, scelta: $filtro)
                Toggle(isOn: $gpu) { VStack(alignment: .leading, spacing: 3) { Text("Graphics on the GPU (PSP)"); Text("The 3D is drawn by the iPhone's graphics chip: faster and sharper (2× with Enhanced Graphics). Turn it off only if a game shows broken graphics.").font(.caption).foregroundColor(.secondary) } }
                FMLABRigaScelta(titolo: "Shape in Landscape", opzioni: FMLABScelte.forma, scelta: $formato)
            } header: { Text("Graphics") } footer: { Text("Tap each item: every choice says what it changes. Valid from the next game you open; Picture, Shape and Quality also change right away from the game menu › Picture.") }
            Section {
                Toggle(isOn: $textureHD) { VStack(alignment: .leading, spacing: 3) { Text("HD Textures (PSP)"); Text("Redraws the game textures at double size with xBRZ: sharper writing and surfaces. The first seconds of a new area can stutter while they are made.").font(.caption).foregroundColor(.secondary) } }
                Toggle(isOn: $coloriLCD) { VStack(alignment: .leading, spacing: 3) { Text("True Handheld Colours (GB Color, GBA)"); Text("The colours as they looked on the real screen, not the over-bright raw ones.").font(.caption).foregroundColor(.secondary) } }
                Toggle(isOn: $sciaLCD) { VStack(alignment: .leading, spacing: 3) { Text("LCD Trail (GB, GBA)"); Text("Blends one frame into the next like the old screens: transparencies and flickering sprites look right.").font(.caption).foregroundColor(.secondary) } }
                FMLABRigaScelta(titolo: "Game Boy Colours", opzioni: FMLABScelte.paletteGB, scelta: $paletteGB)
                FMLABRigaScelta(titolo: "NES Colours", opzioni: FMLABScelte.paletteNES, scelta: $paletteNES)
            } header: { Text("Retro Look") } footer: { Text("Pixel Art HD (in Picture) enlarges NES, Game Boy, GBA and SNES 4× with Scale2x: clean edges instead of steps, then soft. Valid from the next game you open.") }
            Section {
                Toggle("Use the External Screen for Games", isOn: $usaEsterno)
                HStack { Label("External screen", systemImage: "tv"); Spacer(); Text(schermoEsterno ?? LF("None")).foregroundColor(schermoEsterno == nil ? .secondary : .green) }
                NavigationLink { FMLABGuidaTV(perGiochi: true) } label: { Label("Play on the TV…", systemImage: "airplayvideo") }
                FMLABRigaAirPlay()
            } header: { Text("AirPlay and TV") } footer: {
                Text("The AirPlay button (sound only) sends just the audio, like music: the picture stays on the iPhone. iOS lets only Screen Mirroring in Control Center send the picture, or a USB-C/HDMI cable. On DS the iPhone keeps the screens for touch.")
            }
            Section {
                Button { FMLABCopia.esporta { errore = $0 } } label: { Label("Export Backup…", systemImage: "square.and.arrow.up") }
                Button { FMLABSceltaFile.apri(cartella: true) { u in if let u = u.first { errore = FMLABCopia.ripristina(da: u); ricarica() } } } label: { Label("Restore Backup…", systemImage: "arrow.counterclockwise") }
            } header: { Text("Backup") } footer: {
                Text("A folder with your game saves, states, BIOS, covers and Game Emulator settings, to keep in Files or iCloud or to move to another iPhone. Games are not included.")
            }
            Section {
                ForEach(FMLABEmulatore.core(), id: \.nome) { c in
                    let quanti = libreria.conteggio[c.nome] ?? 0
                    HStack(spacing: 12) {
                        FMLABIconaConsole(core: c.nome, lato: 44).opacity(nascoste.contains(c.nome) ? 0.35 : 1)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(FMLABDati.nome(c)).font(.callout.weight(.semibold)); Spacer(); Text(quanti == 1 ? LF("1 game") : String(format: LF("%ld games"), quanti)).font(.caption).foregroundColor(.secondary) }
                            if let n = FMLABDati.nota(c) { Text(n).font(.caption).foregroundColor(.secondary) }
                            Text(c.estensioni.map { "." + $0 }.joined(separator: " ")).font(.caption2.monospaced()).foregroundColor(.secondary).lineLimit(1)
                        }
                        Toggle("", isOn: Binding(get: { !nascoste.contains(c.nome) }, set: { mostra in
                            var n = nascoste; if mostra { n.remove(c.nome) } else { n.insert(c.nome) }
                            nascosteTesto = n.sorted().joined(separator: ","); ricarica()
                        })).labelsHidden()
                    }.padding(.vertical, 2)
                }
            } header: { Text("Consoles") } footer: {
                Text("Turn off a console to hide its games from the list (the files are not touched). On iPhone all the emulators are already inside the app: iOS does not let an app add new programs after it is installed, so here you choose which consoles to see. Native emulators (libretro cores), no JIT needed.")
            }
            Section {
                HStack { Text("Version"); Spacer(); Text(versioneDati).font(.callout.monospaced()).foregroundColor(.secondary) }
                HStack {
                    Text("Last check"); Spacer()
                    Text(FMLABDati.ultimoControllo.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? LF("Never")).foregroundColor(.secondary)
                }
                if !FMLABDati.esito.isEmpty {
                    let e = FMLABDati.esito
                    Label(LF(e == "nuovi" ? "Updated from fmlab-retro" : e == "uguali" ? "Already up to date" : e == "disponibili" ? "New data ready: tap Update Now in Games" : e == "scartati" ? "The downloaded data was not valid and was ignored" : "No connection: using the saved copy"),
                          systemImage: e == "nuovi" || e == "uguali" ? "checkmark.circle.fill" : e == "disponibili" ? "sparkles" : "exclamationmark.triangle.fill")
                        .foregroundColor(e == "nuovi" || e == "uguali" ? .green : e == "disponibili" ? .accentColor : .orange).font(.callout)
                }
                Button {
                    controllando = true
                    FMLABDati.aggiorna(forza: true) { controllando = false; versioneDati = FMLABDati.versione; ricarica() }
                } label: { HStack { Label("Check Now", systemImage: "arrow.triangle.2.circlepath"); if controllando { Spacer(); ProgressView() } } }.disabled(controllando)
            } header: { Text("Engine Data") } footer: {
                Text("Extensions, emulator options, BIOS list and notices come from fmlab-retro (dati/emulatore.json), without a new app: when there is something new FMLAB asks before using it, then cleans up files that are no longer needed. The emulators themselves arrive with app updates.")
            }
        }
        .onAppear { controllaBIOS(); versioneDati = FMLABDati.versione; schermoEsterno = FMLABGiocoController.nomeSchermoEsterno() }
        .onReceive(NotificationCenter.default.publisher(for: FMLABTV.cambiata)) { _ in schermoEsterno = FMLABGiocoController.nomeSchermoEsterno() }
        .onChange(of: copertine) { _ in ricarica() }
        .alert("FMLAB Emulator", isPresented: Binding(get: { errore != nil }, set: { if !$0 { errore = nil } })) { Button("OK") { errore = nil } } message: { Text(errore ?? "") }
    }

    private func controllaBIOS() {
        let elenco = FMLABDati.bios, cartella = FMLABEmulatore.cartellaBIOS()
        DispatchQueue.global(qos: .utility).async {
            var esito: [String: Bool] = [:]
            for b in elenco {
                guard let nome = b["file"], let atteso = b["md5"],
                      let d = try? Data(contentsOf: cartella.appendingPathComponent(nome), options: .mappedIfSafe) else { continue }
                esito[nome] = Insecure.MD5.hash(data: d).map { String(format: "%02x", $0) }.joined() == atteso
            }
            DispatchQueue.main.async { statoBIOS = esito }
        }
    }
}
