// FMLAB Emulator: giocatori 2…4 dallo stesso Wi-Fi.
// Il telefono che ha il gioco aperto ("host") ascolta sulla rete locale; un altro telefono (iPhone con FMLAB Emulator
// o Android con l'APK) si collega e diventa il Controller 2, 3 o 4. L'immagine resta una sola (TV o telefono host):
// è il modo di giocare in due dei giochi pensati per due controller sulla stessa console.
// Protocollo (docs/PROTOCOLLO.md): TCP porta 47654 + Bonjour _fmlab-pad._tcp, messaggi [lunghezza u8][tipo u8][dati].
import Foundation
import Network
import UIKit

enum FMLABProtocollo {
    static let porta: UInt16 = 47654
    static let servizio = "_fmlab-pad._tcp"
    static let versione: UInt8 = 1
    // cliente → host
    static let ciao: UInt8 = 0x01        // [versione][nome utf8]
    static let tasti: UInt8 = 0x02       // [tasti u16 LE][x i16 LE][y i16 LE]
    static let ping: UInt8 = 0x03
    // host → cliente
    static let benvenuto: UInt8 = 0x81   // [giocatore u8 (0 = pieno)][disposizione u8][core: lunghezza u8 + utf8][titolo utf8]
    static let stato: UInt8 = 0x82       // come benvenuto, quando cambia il gioco

    static func messaggio(_ tipo: UInt8, _ dati: [UInt8] = []) -> Data {
        var d = Data([UInt8(min(255, dati.count + 1)), tipo]); d.append(contentsOf: dati.prefix(254)); return d
    }
    static func utf8(_ s: String, max: Int) -> [UInt8] {
        var b = Array(s.utf8); if b.count > max { b = Array(b.prefix(max)); while let u = b.last, u & 0xC0 == 0x80 { b.removeLast() }; if let u = b.last, u >= 0xC0 { b.removeLast() } }
        return b
    }
    /// Toglie dal buffer i messaggi completi.
    static func estrai(_ buffer: inout Data) -> [(UInt8, [UInt8])] {
        var fuori: [(UInt8, [UInt8])] = []
        while let n = buffer.first, n > 0, buffer.count >= Int(n) + 1 {
            let corpo = Array(buffer.dropFirst().prefix(Int(n))); buffer.removeFirst(Int(n) + 1)
            fuori.append((corpo[0], Array(corpo.dropFirst())))
        }
        if buffer.first == 0 { buffer.removeAll() }
        return fuori
    }
}

// MARK: - Host: il telefono con il gioco

struct FMLABGiocatoreRete: Identifiable, Hashable {
    let id: Int          // numero del giocatore (2…4)
    let nome: String
}

final class FMLABRete: ObservableObject {
    static let host = FMLABRete()
    @Published private(set) var giocatori: [FMLABGiocatoreRete] = []
    @Published private(set) var inAscolto = false
    @Published private(set) var errore: String?
    static var acceso: Bool { UserDefaults.standard.object(forKey: "FMLAB.rete") as? Bool ?? true }

    private let coda = DispatchQueue(label: "FMLAB.rete")
    private var ascolto: NWListener?
    private var collegati: [Int: NWConnection] = [:]      // giocatore → connessione (solo sulla coda)
    private var ultimoSegno: [Int: Date] = [:]
    private var giro: DispatchSourceTimer?
    // gioco aperto ora (per il cliente: titolo e tasti giusti)
    private var titolo = "", core = "", disposizione: UInt8 = 2

    func avvia() {
        coda.async { [self] in
            guard ascolto == nil, Self.acceso else { return }
            do {
                let tcp = NWProtocolTCP.Options(); tcp.noDelay = true
                let p = NWParameters(tls: nil, tcp: tcp); p.includePeerToPeer = false; p.allowLocalEndpointReuse = true
                let l = try NWListener(using: p, on: NWEndpoint.Port(rawValue: FMLABProtocollo.porta)!)
                l.service = NWListener.Service(name: UIDevice.current.name, type: FMLABProtocollo.servizio)
                l.stateUpdateHandler = { [weak self] s in
                    guard let self else { return }
                    switch s {
                    case .ready: self.pubblica { $0.inAscolto = true; $0.errore = nil }
                    case .failed(let e): self.pubblica { $0.inAscolto = false; $0.errore = e.localizedDescription }; self.coda.async { self.ascolto?.cancel(); self.ascolto = nil }
                    case .cancelled: self.pubblica { $0.inAscolto = false }
                    default: break
                    }
                }
                l.newConnectionHandler = { [weak self] c in self?.accogli(c) }
                l.start(queue: coda); ascolto = l
                let t = DispatchSource.makeTimerSource(queue: coda); t.schedule(deadline: .now() + 1, repeating: 1)
                t.setEventHandler { [weak self] in self?.controllaSilenzi() }; t.resume(); giro = t
            } catch { pubblica { $0.errore = error.localizedDescription } }
        }
    }
    func ferma() {
        coda.async { [self] in
            ascolto?.cancel(); ascolto = nil; giro?.cancel(); giro = nil
            for (n, c) in collegati { c.cancel(); FMLABEmulatore.rete(porta: n - 1, tasti: 0, x: 0, y: 0) }
            collegati = [:]; ultimoSegno = [:]
            pubblica { $0.giocatori = []; $0.inAscolto = false }
        }
    }
    /// Il gioco aperto cambia (nil = nessun gioco): i controller collegati aggiornano titolo e tasti.
    func gioco(titolo: String?, core: String, disposizione: Int) {
        coda.async { [self] in
            self.titolo = titolo ?? ""; self.core = titolo == nil ? "" : core; self.disposizione = UInt8(clamping: disposizione)
            for (n, c) in collegati {
                c.send(content: statoPer(n, tipo: FMLABProtocollo.stato), completion: .contentProcessed { _ in })
                FMLABEmulatore.rete(porta: n - 1, tasti: 0, x: 0, y: 0)
            }
        }
    }

    private func statoPer(_ n: Int, tipo: UInt8) -> Data {
        var d: [UInt8] = [UInt8(n), disposizione]
        let c = FMLABProtocollo.utf8(core, max: 30); d.append(UInt8(c.count)); d += c
        d += FMLABProtocollo.utf8(titolo, max: 200)
        return FMLABProtocollo.messaggio(tipo, d)
    }
    private func pubblica(_ f: @escaping (FMLABRete) -> Void) { DispatchQueue.main.async { f(self) } }
    private func aggiornaElenco(_ nomi: [Int: String]) {
        let e = nomi.sorted { $0.key < $1.key }.map { FMLABGiocatoreRete(id: $0.key, nome: $0.value) }
        pubblica { $0.giocatori = e }
    }
    private var nomi: [Int: String] = [:]

    private func accogli(_ c: NWConnection) {
        var numero = 0, buffer = Data()
        c.stateUpdateHandler = { [weak self] s in
            guard let self else { return }
            switch s {
            case .failed, .cancelled: self.via(numero, c)
            default: break
            }
        }
        func ricevi() {
            c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] dati, _, fine, err in
                guard let self else { return }
                if let dati { buffer.append(dati) }
                for (tipo, corpo) in FMLABProtocollo.estrai(&buffer) {
                    switch tipo {
                    case FMLABProtocollo.ciao where numero == 0:
                        let libero = (2...4).first { self.collegati[$0] == nil } ?? 0
                        let nome = String(decoding: corpo.dropFirst(), as: UTF8.self)
                        if libero == 0 {
                            c.send(content: FMLABProtocollo.messaggio(FMLABProtocollo.benvenuto, [0]), completion: .contentProcessed { _ in c.cancel() }); return
                        }
                        numero = libero; self.collegati[libero] = c; self.ultimoSegno[libero] = Date()
                        self.nomi[libero] = nome.isEmpty ? LF("Controller") : nome; self.aggiornaElenco(self.nomi)
                        c.send(content: self.statoPer(libero, tipo: FMLABProtocollo.benvenuto), completion: .contentProcessed { _ in })
                    case FMLABProtocollo.tasti where numero > 0 && corpo.count >= 6:
                        let t = UInt32(corpo[0]) | UInt32(corpo[1]) << 8
                        let x = Int16(bitPattern: UInt16(corpo[2]) | UInt16(corpo[3]) << 8), y = Int16(bitPattern: UInt16(corpo[4]) | UInt16(corpo[5]) << 8)
                        FMLABEmulatore.rete(porta: numero - 1, tasti: t, x: x, y: y); self.ultimoSegno[numero] = Date()
                    case FMLABProtocollo.ping where numero > 0:
                        self.ultimoSegno[numero] = Date()
                        c.send(content: FMLABProtocollo.messaggio(FMLABProtocollo.ping), completion: .contentProcessed { _ in })
                    default: break
                    }
                }
                if fine || err != nil { c.cancel(); return }
                ricevi()
            }
        }
        c.start(queue: coda); ricevi()
    }
    private func via(_ numero: Int, _ c: NWConnection) {
        guard numero > 0, collegati[numero] === c else { return }
        collegati[numero] = nil; ultimoSegno[numero] = nil; nomi[numero] = nil
        FMLABEmulatore.rete(porta: numero - 1, tasti: 0, x: 0, y: 0)   // niente tasti bloccati giù
        aggiornaElenco(nomi)
    }
    /// Un controller che tace da 5 s (Wi-Fi perso, app chiusa) si stacca e i suoi tasti si rilasciano.
    private func controllaSilenzi() {
        let ora = Date()
        for (n, quando) in ultimoSegno where ora.timeIntervalSince(quando) > 5 { if let c = collegati[n] { c.cancel(); via(n, c) } }
    }
}

// MARK: - Cliente: questo telefono fa da Controller 2

final class FMLABControllerRete: ObservableObject {
    struct Partita: Identifiable, Hashable { let id: String; let nome: String; let punto: NWEndpoint }
    enum Stato: Equatable { case fermo, cerco, collego, collegato(giocatore: Int), pieno, perso(String) }
    @Published private(set) var partite: [Partita] = []
    @Published private(set) var stato: Stato = .fermo
    @Published private(set) var titolo = ""
    @Published private(set) var core = ""
    @Published private(set) var disposizione = 2

    private let coda = DispatchQueue(label: "FMLAB.controller")
    private var cerca: NWBrowser?
    private var conn: NWConnection?
    private var buffer = Data()
    private var tastiOra: UInt16 = 0, levetta: (Int16, Int16) = (0, 0)
    private var giro: DispatchSourceTimer?

    func cercaPartite() {
        cerca?.cancel()
        let b = NWBrowser(for: .bonjour(type: FMLABProtocollo.servizio, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] risultati, _ in
            let p = risultati.compactMap { r -> Partita? in
                if case let .service(nome, _, _, _) = r.endpoint { return Partita(id: "\(r.endpoint)", nome: nome, punto: r.endpoint) }
                return nil
            }.sorted { $0.nome < $1.nome }
            DispatchQueue.main.async { self?.partite = p }
        }
        b.stateUpdateHandler = { [weak self] s in if case .failed(let e) = s { DispatchQueue.main.async { self?.stato = .perso(e.localizedDescription) } } }
        b.start(queue: coda); cerca = b
        if case .fermo = stato { stato = .cerco }
    }
    func smettiDiCercare() { cerca?.cancel(); cerca = nil }

    func collega(_ punto: NWEndpoint) {
        stacca()
        stato = .collego
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true; tcp.connectionTimeout = 6
        let c = NWConnection(to: punto, using: NWParameters(tls: nil, tcp: tcp))
        c.stateUpdateHandler = { [weak self] s in
            guard let self else { return }
            switch s {
            case .ready:
                var d: [UInt8] = [FMLABProtocollo.versione]; d += FMLABProtocollo.utf8(UIDevice.current.name, max: 40)
                c.send(content: FMLABProtocollo.messaggio(FMLABProtocollo.ciao, d), completion: .contentProcessed { _ in })
            case .failed(let e): DispatchQueue.main.async { self.stato = .perso(e.localizedDescription) }; self.chiudi()
            case .waiting(let e): DispatchQueue.main.async { self.stato = .perso(e.localizedDescription) }
            default: break
            }
        }
        conn = c; c.start(queue: coda); ricevi(c)
        let t = DispatchSource.makeTimerSource(queue: coda); t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in self?.inviaTasti() }   // battito: tiene viva la presa anche senza tasti
        t.resume(); giro = t
    }
    func collega(indirizzo: String) {
        collega(NWEndpoint.hostPort(host: NWEndpoint.Host(indirizzo.trimmingCharacters(in: .whitespaces)), port: NWEndpoint.Port(rawValue: FMLABProtocollo.porta)!))
    }
    func stacca() {
        coda.async { [self] in tastiOra = 0; levetta = (0, 0); inviaTasti() }
        chiudi(); stato = cerca == nil ? .fermo : .cerco
    }
    private func chiudi() { coda.async { [self] in giro?.cancel(); giro = nil; conn?.cancel(); conn = nil; buffer.removeAll() } }

    func tasto(_ t: FMLABTasto, premuto: Bool) {
        coda.async { [self] in
            let bit = UInt16(1) << UInt16(t.rawValue)
            let nuovo = premuto ? tastiOra | bit : tastiOra & ~bit
            guard nuovo != tastiOra else { return }
            tastiOra = nuovo; inviaTasti()
        }
    }
    private func inviaTasti() {
        guard let c = conn else { return }
        let x = UInt16(bitPattern: levetta.0), y = UInt16(bitPattern: levetta.1)
        c.send(content: FMLABProtocollo.messaggio(FMLABProtocollo.tasti, [UInt8(tastiOra & 0xFF), UInt8(tastiOra >> 8), UInt8(x & 0xFF), UInt8(x >> 8), UInt8(y & 0xFF), UInt8(y >> 8)]), completion: .contentProcessed { _ in })
    }
    private func ricevi(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] dati, _, fine, err in
            guard let self, self.conn === c else { return }
            if let dati { self.buffer.append(dati) }
            for (tipo, corpo) in FMLABProtocollo.estrai(&self.buffer) where tipo == FMLABProtocollo.benvenuto || tipo == FMLABProtocollo.stato {
                guard let n = corpo.first else { continue }
                if n == 0 { DispatchQueue.main.async { self.stato = .pieno }; self.chiudi(); return }
                let disp = corpo.count > 1 ? Int(corpo[1]) : 2
                let lc = corpo.count > 2 ? Int(corpo[2]) : 0
                let core = corpo.count >= 3 + lc ? String(decoding: corpo[3..<(3 + lc)], as: UTF8.self) : ""
                let titolo = corpo.count > 3 + lc ? String(decoding: corpo[(3 + lc)...], as: UTF8.self) : ""
                DispatchQueue.main.async { self.stato = .collegato(giocatore: Int(n)); self.disposizione = disp; self.core = core; self.titolo = titolo }
            }
            if fine || err != nil { DispatchQueue.main.async { self.stato = .perso(LF("The game was closed or the Wi-Fi dropped.")) }; self.chiudi(); return }
            self.ricevi(c)
        }
    }
}
