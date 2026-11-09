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
        FMLABMod.prepara()
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
    func sceneDidBecomeActive(_ scene: UIScene) {
        FMLABRete.host.avvia()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { FMLABTV.shared.riprova() }
    }
    func sceneDidEnterBackground(_ scene: UIScene) {
        // in sottofondo iOS chiude comunque le prese: si spegne pulito, così i controller vedono subito il distacco
        FMLABRete.host.ferma()
    }
}

struct FMLABHome: View {
    @State private var scheda = 0
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
        .onAppear { FMLABAggiornamento.shared.controlla() }
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
    @State private var sorgenteCopiata = false
    private func riga(_ t: String, _ icona: String, _ valore: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(red: 0.85, green: 0.16, blue: 0.16)))
            Text(LF(t))
            Spacer()
            if let v = valore { Text(v).foregroundColor(.secondary) }
        }
    }
    private func pagina(_ t: String, _ icona: String, _ parte: FMLABSezioniGioco.Parte, _ valore: String?) -> some View {
        NavigationLink { List { FMLABSezioniGioco(parte: parte) }.listStyle(.insetGrouped).navigationTitle(LF(t)) } label: { riga(t, icona, valore) }
    }
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
                Button { UIPasteboard.general.string = FMLABAggiornamento.sorgente; withAnimation { sorgenteCopiata = true } } label: {
                    Label(sorgenteCopiata ? LF("Source Link Copied") : LF("Copy the FMLAB Source Link"), systemImage: sorgenteCopiata ? "checkmark.circle.fill" : "plus.app")
                }
            } footer: { Text("The app checks for new versions by itself. To see FMLAB updates in LiveContainer too: copy the source link, close this app, then LiveContainer › Sources › + and paste. From there one tap updates the app.") }
            FMLABAvvisoVersione()
            Section {
                pagina("Graphics", "sparkles.tv", .grafica, LF(FMLABScelte.qualita.first { $0.id == FMLABGiocoController.qualita() }?.titolo ?? ""))
                NavigationLink { FMLABComandiView() } label: { riga("Controls Look", "gamecontroller.fill", LF(FMLABTemaComandi.attuale.nome)) }
                pagina("Controls, Sound and Saves", "slider.horizontal.3", .comandi, nil)
                pagina("TV", "tv.fill", .tv, nil)
                pagina("Save Backups", "externaldrive.fill", .copie, nil)
                pagina("Consoles and BIOS", "square.grid.2x2.fill", .console, nil)
                pagina("Advanced", "wrench.and.screwdriver.fill", .avanzate, nil)
            } header: { Text("Games") } footer: { Text("Every page explains what each option does.") }
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
        .onAppear { indirizzo = FMLABProtocollo.indirizzoWiFi()?.ip; if reteAccesa { rete.avvia() } }
    }
}
