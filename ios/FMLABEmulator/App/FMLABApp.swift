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
    var body: some View {
        TabView(selection: $scheda) {
            NavigationView { GameEmulatorView() }.navigationViewStyle(.stack)
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }.tag(0)
            NavigationView { FMLABControllerView() }.navigationViewStyle(.stack)
                .tabItem { Label("Controller 2", systemImage: "wifi") }.tag(1)
            NavigationView { FMLABAltro() }.navigationViewStyle(.stack)
                .tabItem { Label("TV and More", systemImage: "tv") }.tag(2)
        }
        .tint(Color(red: 0.9, green: 0.15, blue: 0.15))
    }
}

/// TV, Wi-Fi, lingua, versione.
struct FMLABAltro: View {
    @ObservedObject private var rete = FMLABRete.host
    @AppStorage("FMLAB.rete") private var reteAccesa = true
    @State private var lingua = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first.map { $0.hasPrefix("it") ? "it" : $0.hasPrefix("en") ? "en" : "" } ?? ""
    @State private var ultima: String?
    @State private var indirizzo = FMLABProtocollo.indirizzoWiFi()?.ip
    private var versione: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    var body: some View {
        List {
            Section {
                HStack { Image("FMLABLogo").resizable().scaledToFit().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading) { Text("FMLAB Emulator").font(.headline); Text(String(format: LF("Version %@"), versione)).font(.caption).foregroundColor(.secondary) } }
                if let u = ultima, u != versione {
                    Button { UIPasteboard.general.string = FMLABInfo.linkIPA } label: { Label(String(format: LF("Version %@ is ready: copy the link for LiveContainer"), u), systemImage: "arrow.down.circle.fill") }
                }
            }
            Section {
                NavigationLink { FMLABGuidaTV(perGiochi: true) } label: { Label("Play on the TV…", systemImage: "airplayvideo") }
                FMLABRigaAirPlay()
            } header: { Text("TV") } footer: { Text("With Screen Mirroring or a USB-C/HDMI cable the TV shows only the game, in full screen, and the iPhone becomes the controller. Without a game open the TV shows the FMLAB logo.") }
            Section {
                Toggle("Players 2–4 from Wi-Fi", isOn: $reteAccesa)
                    .onChange(of: reteAccesa) { acceso in if acceso { rete.avvia() } else { rete.ferma() } }
                HStack { Label("Ready on Wi-Fi", systemImage: "wifi"); Spacer(); Text(rete.inAscolto ? LF("Yes") : LF("No")).foregroundColor(rete.inAscolto ? .green : .secondary) }
                if let ip = indirizzo { HStack { Label("Address of this iPhone", systemImage: "number"); Spacer(); Text(ip).font(.body.monospacedDigit()).foregroundColor(.secondary).textSelection(.enabled) } }
                ForEach(rete.giocatori) { g in HStack { Label(String(format: LF("Player %d"), g.id), systemImage: "gamecontroller"); Spacer(); Text(g.nome).foregroundColor(.secondary) } }
                if let e = rete.errore, !rete.inAscolto { Text(e).font(.caption).foregroundColor(.orange) }
                if rete.senzaBonjour && rete.inAscolto { Text("Automatic announcement is blocked here (LiveContainer): the other phone finds this iPhone by searching the Wi-Fi, or type the address above.").font(.caption).foregroundColor(.secondary) }
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
                Link(destination: URL(string: FMLABInfo.repo)!) { Label("Project on GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            } footer: { Text("No games or BIOS are included or downloaded by FMLAB: use your own copies.") }
        }
        .navigationTitle(LF("TV and More"))
        .onAppear { FMLABInfo.ultimaVersione { ultima = $0 }; indirizzo = FMLABProtocollo.indirizzoWiFi()?.ip; if reteAccesa { rete.avvia() } }
    }
}

enum FMLABInfo {
    static let repo = "https://github.com/cipherdesk007-max/emulator-ios-andorid"
    static let linkIPA = repo + "/releases/download/ultima/FMLAB-Emulator.ipa"
    static func ultimaVersione(_ fatto: @escaping (String?) -> Void) {
        var r = URLRequest(url: URL(string: repo + "/releases/download/ultima/VERSIONE.txt")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        r.setValue("FMLAB-Emulator", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: r) { d, risposta, _ in
            let v = (risposta as? HTTPURLResponse)?.statusCode == 200 ? d.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            DispatchQueue.main.async { fatto(v?.count ?? 0 < 20 ? v : nil) }
        }.resume()
    }
}
