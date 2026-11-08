// FMLAB Emulator: una scelta spiegata. Ogni voce dice cosa fa, così si sceglie sapendo cosa cambia.
import SwiftUI

struct FMLABOpzione: Identifiable {
    let id: String
    let titolo: String
    let spiega: String
}

/// Riga delle impostazioni che apre la pagina della scelta e mostra quella attuale.
struct FMLABRigaScelta: View {
    let titolo: String
    var nota: String? = nil
    let opzioni: [FMLABOpzione]
    @Binding var scelta: String
    var body: some View {
        NavigationLink {
            FMLABPaginaScelta(titolo: titolo, nota: nota, opzioni: opzioni, scelta: $scelta)
        } label: {
            HStack { Text(LF(titolo)); Spacer(); Text(LF(opzioni.first { $0.id == scelta }?.titolo ?? "")).foregroundColor(.secondary) }
        }
    }
}

struct FMLABPaginaScelta: View {
    let titolo: String
    let nota: String?
    let opzioni: [FMLABOpzione]
    @Binding var scelta: String
    var body: some View {
        List {
            Section {
                ForEach(opzioni) { o in
                    Button { scelta = o.id } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: scelta == o.id ? "checkmark.circle.fill" : "circle").foregroundColor(scelta == o.id ? .accentColor : .secondary).font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LF(o.titolo)).font(.body.weight(.semibold)).foregroundColor(.primary)
                                Text(LF(o.spiega)).font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            } footer: { if let n = nota { Text(LF(n)) } }
        }
        .navigationTitle(LF(titolo))
    }
}

/// Tutte le scelte della grafica, con le spiegazioni.
enum FMLABScelte {
    static let qualita = [
        FMLABOpzione(id: "originale", titolo: "Original", spiega: "The real resolution of the console. The lightest: for older phones or if a game slows down."),
        FMLABOpzione(id: "migliorata", titolo: "Enhanced", spiega: "The 3D is drawn at double size: PSP 960×544, DS 512×384, PlayStation 2×, SNES Mode 7 2×. Much sharper, runs well on recent iPhones."),
        FMLABOpzione(id: "massima", titolo: "Maximum", spiega: "At triple size: PSP 1440×816, DS 768×576, SNES Mode 7 4×. Made for the TV. On DS the heaviest 3D games can slow down: then use Enhanced."),
    ]
    static let filtro = [
        FMLABOpzione(id: "netti", titolo: "Sharp Pixels", spiega: "Each pixel stays a crisp square, like the real screen. For 2D games. 3D games (PSP, and PlayStation and DS when drawn bigger) are always smooth anyway."),
        FMLABOpzione(id: "hd", titolo: "Pixel Art HD", spiega: "NES, Game Boy, GBA and SNES: outlines rebuilt (Scale2x 4×) and then smoothed. No stair steps, a remaster look. The best on the TV for 2D games."),
        FMLABOpzione(id: "morbido", titolo: "Smooth", spiega: "Everything gently blended: no visible pixels, a little less sharp."),
        FMLABOpzione(id: "tv", titolo: "TV (scanlines)", spiega: "The dark lines of an old tube television, for the arcade feeling."),
        FMLABOpzione(id: "lcd", titolo: "Handheld LCD", spiega: "The grid of a Game Boy screen."),
    ]
    static let forma = [
        FMLABOpzione(id: "originale", titolo: "Original", spiega: "The true shape of the console, with black bands at the sides. Circles stay round."),
        FMLABOpzione(id: "largo", titolo: "Wide 16:9", spiega: "Stretched to 16:9: fills modern TVs, round things look slightly oval."),
        FMLABOpzione(id: "pieno", titolo: "Fill the Screen", spiega: "Fills the whole screen, even if it distorts."),
    ]
    static let paletteGB = [
        FMLABOpzione(id: "auto", titolo: "Automatic", spiega: "Uses the colours the game has for the Super Game Boy or Game Boy Color (Pokémon, Zelda, Mario get theirs); the others get a colour set."),
        FMLABOpzione(id: "dmg", titolo: "Classic Green", spiega: "The green of the original 1989 Game Boy."),
        FMLABOpzione(id: "pocket", titolo: "Pocket", spiega: "The grey-olive tones of the Game Boy Pocket."),
        FMLABOpzione(id: "light", titolo: "Light", spiega: "The blue-green backlight of the Game Boy Light."),
        FMLABOpzione(id: "grigio", titolo: "Grey", spiega: "Pure black and white, the most neutral."),
    ]
    static let paletteNES = [
        FMLABOpzione(id: "smooth-fbx", titolo: "Natural", spiega: "Balanced, natural colours (Smooth FBX): the best on modern screens."),
        FMLABOpzione(id: "nescap", titolo: "Real Console", spiega: "Measured from a real NES on a TV of the time (NESCAP)."),
        FMLABOpzione(id: "nes-classic-fbx-fs", titolo: "Classic Mini", spiega: "Like the NES Classic Mini, a little brighter."),
        FMLABOpzione(id: "default", titolo: "Emulator Default", spiega: "The emulator's own colours, more saturated."),
    ]
    static let suonoVeloce = [
        FMLABOpzione(id: "muto", titolo: "Muted", spiega: "Silence while the game runs faster: no crackling, sped-up sound."),
        FMLABOpzione(id: "accelerato", titolo: "Sped Up", spiega: "You hear the sound, faster and choppy."),
    ]
}
