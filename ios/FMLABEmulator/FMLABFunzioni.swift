// FMLAB Emulator: funzioni comuni (lingua, AirPlay, guida TV). AirPlay e guida vengono da FMLAB Linux.
import SwiftUI
import UIKit
import AVKit
import AVFoundation

// MARK: - Lingua
/// Testo tradotto (it.lproj) per le stringhe che non passano da Text("...")
func LF(_ s: String) -> String { NSLocalizedString(s, comment: "") }

// MARK: AirPlay: cerca le TV vicine senza uscire dall'app
/// Elenco di sistema dei dispositivi AirPlay (Apple TV, TV AirPlay, Mac). Sceglierne uno manda lì il suono;
/// l'immagine la manda solo Duplica schermo del Centro di Controllo (iOS non lascia avviarla a un'app).
final class FMLABAirPlay {
    private static let scelta: AVRoutePickerView = {
        let v = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        v.prioritizesVideoDevices = true
        return v
    }()
    /// Apre l'elenco da qualunque punto (menu del gioco, Impostazioni).
    static func apri(da vista: UIView) {
        let v = scelta
        if v.superview !== vista { v.removeFromSuperview(); v.alpha = 0.02; vista.addSubview(v) }
        for case let b as UIButton in v.subviews { b.sendActions(for: .touchUpInside); return }
    }
}
struct FMLABSceltaAirPlay: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView(); v.prioritizesVideoDevices = true
        v.tintColor = .clear; v.activeTintColor = .clear; v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ v: AVRoutePickerView, context: Context) {}
}
/// Riga "Cerca TV AirPlay…": tutta la riga apre l'elenco di sistema.
struct FMLABRigaAirPlay: View {
    var body: some View {
        ZStack {
            HStack { Label("Sound Only to AirPlay…", systemImage: "airplayaudio"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }
            FMLABSceltaAirPlay()
        }
    }
}


// MARK: Guida "Usa la TV": Duplica schermo (immagine) contro AirPlay del suono, con lo stato dal vivo
/// iOS lascia mandare l'immagine solo a Duplica schermo del Centro di Controllo (nessuna app può avviarla):
/// questa scheda lo spiega e si accorge da sola quando la duplicazione parte.
struct FMLABGuidaTV: View {
    var perGiochi = true
    var chiudi: (() -> Void)? = nil
    @State private var duplica = false
    @State private var separato = false
    @State private var diagnosi = ""
    @State private var suono = ""
    private let giro = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private func aggiorna() {
        separato = FMLABTV.shared.scena != nil
        duplica = separato || UIScreen.screens.count > 1
        diagnosi = FMLABTV.shared.diagnosi
        suono = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portName }.joined(separator: ", ")
    }
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: separato ? "checkmark.circle.fill" : duplica ? "exclamationmark.triangle.fill" : "rectangle.on.rectangle").font(.title2).foregroundColor(separato ? .green : duplica ? .orange : .accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(separato ? "The TV is ready for the game" : duplica ? "The TV is copying the iPhone" : "Screen Mirroring is off").font(.headline)
                        Text(separato ? "The TV shows Waiting for the game: open a game, it goes there and the iPhone becomes the controller." : duplica ? "iOS chose to copy the whole phone, because Screen Mirroring started before FMLAB asked for its own TV screen." : "The TV gets the picture only with Screen Mirroring.").font(.callout).foregroundColor(.secondary)
                    }
                }.padding(.vertical, 4)
                if !suono.isEmpty { HStack { Label("Sound", systemImage: "speaker.wave.2"); Spacer(); Text(suono).foregroundColor(.secondary) } }
            }
            if duplica && !separato {
                Section {
                    Label("Open Control Center › Screen Mirroring › Stop Mirroring.", systemImage: "1.circle.fill")
                    Label("Come back to FMLAB Emulator and leave it open.", systemImage: "2.circle.fill")
                    Label("Start Screen Mirroring again and choose your TV: now iOS gives the game its own screen (the TV turns black with Waiting for the game).", systemImage: "3.circle.fill")
                    Button { FMLABTV.shared.riprova(); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { aggiorna() } } label: { Label("Try Again Without Stopping", systemImage: "arrow.clockwise") }
                } header: { Text("Fix It") } footer: { Text("iOS decides it only when mirroring starts. FMLAB Linux works the same way. If you use Fire TV or another TV with an AirPlay receiver app, it works the same as Apple TV.") }
            }
            if !duplica {
                Section {
                    Label("Swipe down from the top-right corner to open Control Center.", systemImage: "1.circle.fill")
                    Label("Tap Screen Mirroring: the two overlapping rectangles. If it is missing, hold on Control Center › + › Screen Mirroring.", systemImage: "2.circle.fill")
                    Label("Choose your Apple TV or AirPlay TV and come back here.", systemImage: "3.circle.fill")
                } header: { Text("Picture on the TV") } footer: {
                    Text("iOS does not let any app start Screen Mirroring by itself: it is only in Control Center. The iPhone and the TV must be on the same Wi-Fi. A USB-C/HDMI cable works too, with nothing to tap.")
                }
            }
            Section {
                FMLABRigaAirPlay()
                Text(diagnosi).font(.caption2.monospaced()).foregroundColor(.secondary).textSelection(.enabled)
            } footer: { Text("Sends only the sound (like music from Spotify): the picture stays on the iPhone.") }
        }
        .navigationTitle(LF("Play on the TV"))
        .toolbar { ToolbarItem(placement: .confirmationAction) { if let chiudi { Button("Done") { chiudi() } } } }
        .onAppear(perform: aggiorna)
        .onReceive(giro) { _ in aggiorna() }
    }
}
