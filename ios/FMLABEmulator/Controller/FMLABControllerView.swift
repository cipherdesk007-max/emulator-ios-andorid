// FMLAB Emulator: questo iPhone fa da Controller 2 (o 3, 4) per un gioco aperto su un altro telefono dello stesso Wi-Fi.
import SwiftUI
import UIKit
import Combine

struct FMLABControllerView: View {
    @StateObject private var rete = FMLABControllerRete()
    @State private var indirizzo = ""
    @State private var inGioco = false
    var body: some View {
        List {
            Section {
                if rete.cercoNellaRete || rete.partite.isEmpty {
                    HStack(spacing: 12) { if rete.cercoNellaRete { ProgressView() }; Text(rete.cercoNellaRete ? "Looking for FMLAB Emulator on this Wi-Fi…" : "Nothing found: open a game on the other iPhone, then search again.").foregroundColor(.secondary) }
                }
                ForEach(rete.partite) { p in
                    Button { rete.collega(p.punto) } label: {
                        HStack { Label(p.nome, systemImage: "iphone.gen3"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }
                    }
                }
                Button { rete.cercaNellaRete() } label: { Label("Search Again", systemImage: "arrow.clockwise") }.disabled(rete.cercoNellaRete)
            } header: { Text("Games Nearby") } footer: {
                Text("On the other iPhone open FMLAB Emulator and a game. Both phones on the same Wi-Fi; the first time iOS asks for Local Network access: allow it.")
            }
            Section {
                TextField(LF("IP address (e.g. 192.168.1.20)"), text: $indirizzo)
                    .keyboardType(.numbersAndPunctuation).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Connect") { rete.collega(indirizzo: indirizzo) }.disabled(indirizzo.isEmpty)
            } header: { Text("By Address") } footer: { Text("If the iPhone does not appear (some routers block discovery): its address is in Settings › Wi-Fi › ⓘ.") }
            switch rete.stato {
            case .collego: Section { HStack { ProgressView(); Text("Connecting…") } }
            case .pieno: Section { Label("That game already has 4 players.", systemImage: "person.3.fill").foregroundColor(.orange) }
            case .perso(let m): Section { Label(m, systemImage: "wifi.exclamationmark").foregroundColor(.orange) }
            default: EmptyView()
            }
        }
        .navigationTitle(LF("Controller 2"))
        .onAppear { rete.cercaPartite() }
        .onDisappear { if !inGioco { rete.smettiDiCercare() } }
        .onReceive(rete.$stato) { s in if case .collegato = s { inGioco = true } }
        .fullScreenCover(isPresented: $inGioco, onDismiss: { rete.stacca() }) {
            FMLABPadRemotoSchermo(rete: rete) { inGioco = false }.ignoresSafeArea()
        }
    }
}

struct FMLABPadRemotoSchermo: UIViewControllerRepresentable {
    let rete: FMLABControllerRete
    let esci: () -> Void
    func makeUIViewController(context: Context) -> FMLABPadRemoto { FMLABPadRemoto(rete: rete, esci: esci) }
    func updateUIViewController(_ c: FMLABPadRemoto, context: Context) {}
}

/// Gli stessi tasti del gioco (FMLABPad), ma vanno all'altro telefono.
final class FMLABPadRemoto: UIViewController {
    private let rete: FMLABControllerRete
    private let esci: () -> Void
    private let pad = FMLABPad()
    private let testa = UILabel()
    private var osservati = Set<AnyCancellable>()
    init(rete: FMLABControllerRete, esci: @escaping () -> Void) { self.rete = rete; self.esci = esci; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)
        testa.textColor = .white; testa.textAlignment = .center; testa.numberOfLines = 2
        testa.font = .preferredFont(forTextStyle: .headline)
        view.addSubview(testa)
        pad.tasto = { [weak self] t, giu in self?.rete.tasto(t, premuto: giu) }
        pad.menu = { [weak self] in self?.chiediUscita() }
        pad.veloce = { _ in }        // l'avanti veloce lo decide solo il giocatore 1
        pad.mostraVeloce = false
        view.addSubview(pad)
        rete.$stato.combineLatest(rete.$titolo, rete.$core, rete.$disposizione).receive(on: DispatchQueue.main).sink { [weak self] stato, titolo, core, disp in
            guard let self else { return }
            switch stato {
            case .collegato(let n):
                self.testa.text = String(format: LF("Player %d"), n) + " · " + (titolo.isEmpty ? LF("waiting for a game…") : titolo)
                if self.pad.disposizione != disp { self.pad.disposizione = disp }
                self.pad.nomeCore = core; self.view.setNeedsLayout()
            case .perso, .pieno, .fermo, .cerco: self.esci()
            case .collego: break
            }
        }.store(in: &osservati)
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); UIApplication.shared.isIdleTimerDisabled = true }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); UIApplication.shared.isIdleTimerDisabled = false }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds, s = view.safeAreaLayoutGuide.layoutFrame, v = b.height >= b.width
        testa.frame = CGRect(x: s.minX + 60, y: s.minY + 6, width: s.width - 120, height: 44)
        // come sul telefono con il gioco sulla TV: tutto lo schermo è per i tasti
        pad.sopra = false
        pad.modo = v ? .verticale : .orizzontale
        pad.frame = v ? CGRect(x: 0, y: b.height * 0.25, width: b.width, height: b.height * 0.75) : b
        pad.areaSicura = UIEdgeInsets(top: v ? 0 : s.minY, left: s.minX, bottom: b.maxY - s.maxY, right: b.maxX - s.maxX)
        pad.spazioLato = v ? 0 : b.width / 3
        pad.chiavePosizioni = "FMLAB.tasti.remoto.\(pad.nomeCore).\(v ? "v" : "o")"
    }

    private func chiediUscita() {
        let m = UIAlertController(title: testa.text, message: LF("Leave the game? The other players keep playing."), preferredStyle: .alert)
        m.addAction(UIAlertAction(title: LF("Edit Buttons"), style: .default) { [weak self] _ in self?.pad.modifica = true })
        m.addAction(UIAlertAction(title: LF("Leave"), style: .destructive) { [weak self] _ in self?.esci() })
        m.addAction(UIAlertAction(title: LF("Cancel"), style: .cancel))
        present(m, animated: true)
    }
}
