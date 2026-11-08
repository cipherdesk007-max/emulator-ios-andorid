// FMLAB Emulator: avvio dell'app. Ciclo di vita UIKit (AppDelegate + scene) come in FMLAB Linux, perché è quello
// che permette di avere la scena della TV separata (TV/FMLABTV.swift).
import SwiftUI
import UIKit

@main
final class FMLABAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let it = (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("it")
        UserDefaults.standard.set(it ? "it" : "en", forKey: "FMLAB.lingua")   // titoli DS e note dei dati nella lingua dell'app
        UserDefaults.standard.set(false, forKey: "FMLAB.giochi.inCorso")
        FMLABEmulatore.preparaCartelle()
        FMLABDati.carica()
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if session.role == .windowApplication {
            let c = UISceneConfiguration(name: "App", sessionRole: session.role); c.delegateClass = FMLABScena.self; return c
        }
        // TV: AirPlay Duplica schermo o cavo (iOS 15–26 dal manifest, iOS 27 dall'accessorio)
        let c = UISceneConfiguration(name: "TV", sessionRole: session.role); c.delegateClass = FMLABTVScena.self; return c
    }
}

@objc(FMLABScena)
final class FMLABScena: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let radice = UIHostingController(rootView: FMLABHome())
        w.rootViewController = radice
        w.makeKeyAndVisible(); window = w
        // subito, prima che parta Duplica schermo: su iOS 27 è ora che si chiede lo schermo separato
        FMLABTV.shared.registra(radice)
    }
    func sceneDidBecomeActive(_ scene: UIScene) { FMLABRete.host.avvia() }
    func sceneDidEnterBackground(_ scene: UIScene) {
        // in sottofondo iOS chiude comunque le prese: si spegne pulito, così i controller vedono subito il distacco
        FMLABRete.host.ferma()
    }
}

struct FMLABHome: View {
    @State private var scheda = 0
    @State private var trasloco = false
    @Environment(\.scenePhase) private var fase
    var body: some View {
        TabView(selection: $scheda) {
            NavigationView { GameEmulatorView() }.navigationViewStyle(.stack)
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }.tag(0)
            NavigationView { FMLABControllerView() }.navigationViewStyle(.stack)
                .tabItem { Label("Controller 2", systemImage: "wifi") }.tag(1)
            NavigationView { FMLABImpostazioni() }.navigationViewStyle(.stack)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(2)
        }
        .tint(Color(red: 0.9, green: 0.15, blue: 0.15))
        .sheet(isPresented: $trasloco) { NavigationView { FMLABTraslocoView(chiudi: { trasloco = false }, avviaSubito: true) } }
        .onAppear {
            FMLABAggiornamento.shared.controlla()
            // prima apertura: se FMLAB Linux è in LiveContainer, i giochi e i salvataggi si portano qui da soli
            guard UserDefaults.standard.object(forKey: FMLABTrasloco.chiaveFatto) == nil, !UserDefaults.standard.bool(forKey: "FMLAB.trasloco.proposto") else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let t = FMLABTrasloco.cercaFMLABLinux()
                DispatchQueue.main.async { if t != nil { UserDefaults.standard.set(true, forKey: "FMLAB.trasloco.proposto"); trasloco = true } }
            }
        }
        .onChange(of: fase) { f in if f == .active { FMLABAggiornamento.shared.controlla() } }
    }
}

/// Tutte le impostazioni, in un posto solo e in ordine: app, giochi, comandi, grafica, TV, Wi-Fi, lingua.
struct FMLABImpostazioni: View {
    @ObservedObject private var rete = FMLABRete.host
    @ObservedObject private var agg = FMLABAggiornamento.shared
    @AppStorage("FMLAB.rete") private var reteAccesa = true
    @State private var lingua = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first.map { $0.hasPrefix("it") ? "it" : $0.hasPrefix("en") ? "en" : "" } ?? ""
    @State private var indirizzo = FMLABProtocollo.indirizzoWiFi()?.ip
    @State private var trasloco = false
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("FMLABLogo").resizable().scaledToFit().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FMLAB Emulator").font(.title3.weight(.bold))
                        Text(String(format: LF("Version %@"), FMLABAggiornamento.attuale)).font(.caption).foregroundColor(.secondary)
                        if agg.nuova == nil, agg.ultimoControllo != nil { Label("Up to date", systemImage: "checkmark.seal.fill").font(.caption).foregroundColor(.green) }
                    }
                    Spacer()
                    if agg.controllando { ProgressView() } else { Button { agg.controlla(forza: true) } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless).accessibilityLabel(LF("Check for Updates")) }
                }.padding(.vertical, 4)
                Button { agg.aggiungiSorgente() } label: { Label("Add FMLAB to LiveContainer Sources", systemImage: "plus.app") }
            } footer: { Text("The app checks for new versions by itself. With the source added, LiveContainer shows FMLAB updates in its Sources tab too.") }
            FMLABAvvisoVersione()
            Section {
                Button { trasloco = true } label: { Label("Bring Games from FMLAB Linux…", systemImage: "arrow.right.doc.on.clipboard") }
            } header: { Text("Your Games") } footer: { Text("Finds FMLAB Linux on this iPhone by itself and brings games, saves and settings here. You can repeat it: only what is newer there is copied.") }
            FMLABSezioniGioco()
            Section {
                Toggle("Players 2–4 from Wi-Fi", isOn: $reteAccesa)
                    .onChange(of: reteAccesa) { acceso in if acceso { rete.avvia() } else { rete.ferma() } }
                HStack { Label("Ready on Wi-Fi", systemImage: "wifi"); Spacer(); Text(rete.inAscolto ? LF("Yes") : LF("No")).foregroundColor(rete.inAscolto ? .green : .secondary) }
                if let ip = indirizzo { HStack { Label("Address of this iPhone", systemImage: "number"); Spacer(); Text(ip).font(.body.monospacedDigit()).foregroundColor(.secondary).textSelection(.enabled) } }
                ForEach(rete.giocatori) { g in HStack { Label(String(format: LF("Player %d"), g.id), systemImage: "gamecontroller"); Spacer(); Text(g.nome).foregroundColor(.secondary) } }
                if let e = rete.errore, !rete.inAscolto { Text(e).font(.caption).foregroundColor(.orange) }
            } header: { Text("Play Together") } footer: {
                Text("On the same Wi-Fi, a friend opens FMLAB Emulator (iPhone) or FMLAB Controller (Android) › Controller 2 and taps this iPhone: they become player 2, 3 or 4 of the game open here. Works with games made for two controllers on one console (SNES, PS1, NES…). The first time iOS asks for Local Network access: allow it.")
            }
            Section {
                Picker("Language", selection: $lingua) { Text("System").tag(""); Text("Italiano").tag("it"); Text("English").tag("en") }
                    .onChange(of: lingua) { l in
                        if l.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") } else { UserDefaults.standard.set([l], forKey: "AppleLanguages") }
                    }
            } footer: { Text("Takes effect the next time you open the app.") }
            Section {
                Link(destination: URL(string: FMLABAggiornamento.pagina)!) { Label("Project on GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            } footer: { Text("No games or BIOS are included or downloaded by FMLAB: use your own copies.") }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(LF("Settings"))
        .sheet(isPresented: $trasloco) { NavigationView { FMLABTraslocoView(chiudi: { trasloco = false }, avviaSubito: false) } }
        .onAppear { indirizzo = FMLABProtocollo.indirizzoWiFi()?.ip; if reteAccesa { rete.avvia() } }
    }
}
