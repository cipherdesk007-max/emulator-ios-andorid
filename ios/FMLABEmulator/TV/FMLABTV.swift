// FMLAB Emulator: la TV come schermo separato, con lo stesso metodo che in FMLAB Linux porta il desktop sulla TV
// (LinuxRunner: LRExternalDisplaySceneDelegate + LRExternalDisplayController).
//  - iOS dà all'app una scena "schermo esterno non interattivo" (Duplica schermo AirPlay o cavo USB-C/HDMI);
//    su iOS 27 solo se l'app ha registrato l'accessorio (FMLABTVAccessorio.m) prima che parta la duplicazione.
//  - La scena ha UNA finestra, creata qui, con un controller fisso: scritta di attesa finché non c'è un gioco,
//    poi l'area dove il gioco disegna. Nessuna finestra in più sopra o sotto (era il punto debole di prima).
//  - La finestra non diventa mai "key": tocchi e tasti restano sul telefono, che diventa il controller.
import UIKit

@objc(FMLABTVScena)
final class FMLABTVScena: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        FMLABTV.shared.collega(ws, delegato: self)
    }
    func sceneDidDisconnect(_ scene: UIScene) { FMLABTV.shared.stacca(scene); window = nil }
}

final class FMLABTV {
    static let shared = FMLABTV()
    static let cambiata = Notification.Name("FMLABTVCambiata")
    /// Impostazioni › TV › "Usa la TV per i giochi" (stessa chiave della versione dentro FMLAB Linux).
    static var accesa: Bool { UserDefaults.standard.object(forKey: "FMLAB.giochi.esterno") as? Bool ?? true }

    private(set) weak var scena: UIWindowScene?
    private var finestra: UIWindow?
    private let schermo = FMLABTVController()
    /// Controller della finestra principale, dove è registrato l'accessorio di iOS 27.
    weak var principale: UIViewController?
    private(set) var statoAccessorio = "non serve"
    private var osservatore: NSObjectProtocol?

    /// Dove il gioco mette la sua immagine; nil se la TV non c'è o è spenta nelle impostazioni.
    var area: UIView? { finestra != nil && Self.accesa ? schermo.area : nil }
    var nome: String? {
        guard let s = scena else { return UIScreen.screens.count > 1 ? LF("Mirroring: open a game") : nil }
        let m = s.screen.bounds.size, k = s.screen.scale
        return String(format: LF("Connected · %.0f×%.0f"), m.width * k, m.height * k)
    }

    /// Duplica schermo è attiva ma iOS non ci ha dato lo schermo separato (copia il telefono).
    var soloDuplicazione: Bool { scena == nil && UIScreen.screens.count > 1 }
    /// Stato leggibile (Impostazioni › TV e Copia rapporto): serve per capire cosa fa iOS.
    var diagnosi: String {
        let ruoli = UIApplication.shared.connectedScenes.map { $0.session.role.rawValue.replacingOccurrences(of: "UIWindowSceneSessionRole", with: "") }.sorted().joined(separator: ", ")
        return "iOS 27: \(statoAccessorio) · scena TV: \(scena != nil ? "sì" : "no") · schermi: \(UIScreen.screens.count) · scene: \(ruoli)"
    }
    private var ultimaRiprova = Date.distantPast
    /// iOS decide "schermo separato o copia" quando parte Duplica schermo. Se è partita prima che l'app chiedesse lo
    /// schermo (es. aperta mentre si duplicava già), si spegne e si riaccende la richiesta: a volte iOS ci ripensa.
    func riprova() {
        guard soloDuplicazione, Self.accesa, let p = principale, Date().timeIntervalSince(ultimaRiprova) > 4 else { return }
        ultimaRiprova = Date()
        FMLABAbilitaSchermoEsterno(p, false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { FMLABAbilitaSchermoEsterno(p, Self.accesa); self.avvisa() }
    }

    /// Chiamata appena c'è la finestra principale: su iOS 27 è il momento di chiedere lo schermo separato.
    func registra(_ controller: UIViewController) {
        principale = controller
        statoAccessorio = FMLABRegistraSchermoEsterno(controller, FMLABTVScena.self)
        FMLABAbilitaSchermoEsterno(controller, Self.accesa)
        if osservatore == nil {
            var ultima = Self.accesa
            osservatore = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, Self.accesa != ultima else { return }
                ultima = Self.accesa
                if let p = self.principale { FMLABAbilitaSchermoEsterno(p, ultima) }
                self.aggiorna()
            }
        }
    }

    func collega(_ ws: UIWindowScene, delegato: FMLABTVScena) {
        scena = ws
        if finestra == nil || finestra?.windowScene !== ws {
            finestra?.isHidden = true
            let w = UIWindow(windowScene: ws)
            w.rootViewController = schermo
            w.backgroundColor = .black
            w.isHidden = false          // mai key: input sul telefono
            finestra = w
        }
        delegato.window = finestra
        aggiorna()
    }
    func stacca(_ s: UIScene) {
        guard s === scena || scena == nil else { return }
        finestra?.isHidden = true; finestra = nil; scena = nil
        schermo.giocoSu(nil)
        avvisa()
    }
    /// Il gioco ha preso (titolo) o lasciato (nil) la TV.
    func inUso(_ titolo: String?) { schermo.giocoSu(titolo) }

    private func aggiorna() {
        // TV spenta nelle impostazioni: la finestra si nasconde (iOS 15–26 tornano a duplicare il telefono)
        finestra?.isHidden = !Self.accesa
        avvisa()
    }
    private func avvisa() { NotificationCenter.default.post(name: Self.cambiata, object: nil) }
}

/// Quello che si vede sulla TV.
final class FMLABTVController: UIViewController {
    let area = UIView()
    private let attesa = UIView()
    private let logo = UIImageView(image: UIImage(named: "FMLABLogo"))
    private let testo = UILabel()
    private let giocatori = UILabel()
    private var osservatore: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        area.backgroundColor = .black
        area.frame = view.bounds; area.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(area)
        logo.contentMode = .scaleAspectFit
        testo.numberOfLines = 0; testo.textAlignment = .center; testo.textColor = UIColor(white: 0.85, alpha: 1)
        testo.font = .systemFont(ofSize: 30, weight: .medium)
        testo.text = LF("Waiting for the game…") + "\n\n" + LF("Open a game on the iPhone: the TV shows only the game, the iPhone becomes the controller.")
        attesa.addSubview(logo); attesa.addSubview(testo)
        view.addSubview(attesa)
        giocatori.textColor = .white; giocatori.font = .systemFont(ofSize: 22, weight: .semibold)
        giocatori.backgroundColor = UIColor(white: 0, alpha: 0.6); giocatori.layer.cornerRadius = 10; giocatori.clipsToBounds = true
        giocatori.textAlignment = .center; giocatori.alpha = 0
        view.addSubview(giocatori)
        osservatore = NotificationCenter.default.addObserver(forName: FMLABTV.giocatoriCambiati, object: nil, queue: .main) { [weak self] n in
            self?.mostraGiocatori(n.object as? String)
        }
    }
    deinit { if let o = osservatore { NotificationCenter.default.removeObserver(o) } }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds, l = min(b.width, b.height) * 0.45, w = b.width * 0.75
        let h = testo.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height
        attesa.frame = b
        let alto = (b.height - l - 28 - h) / 2
        logo.frame = CGRect(x: (b.width - l) / 2, y: alto, width: l, height: l)
        testo.frame = CGRect(x: (b.width - w) / 2, y: alto + l + 28, width: w, height: h)
    }

    func giocoSu(_ titolo: String?) {
        attesa.isHidden = titolo != nil
    }
    private func mostraGiocatori(_ t: String?) {
        guard let t, isViewLoaded else { return }
        giocatori.text = "  " + t + "  "; giocatori.sizeToFit()
        giocatori.frame.size.height += 14
        giocatori.center = CGPoint(x: view.bounds.midX, y: view.bounds.minY + 50)
        view.bringSubviewToFront(giocatori)
        UIView.animate(withDuration: 0.25) { self.giocatori.alpha = 1 } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 4) { self.giocatori.alpha = 0 }
        }
    }
}

extension FMLABTV {
    /// Messaggio breve sulla TV (es. "Giocatore 2 collegato"): oggetto = testo.
    static let giocatoriCambiati = Notification.Name("FMLABTVGiocatori")
}
