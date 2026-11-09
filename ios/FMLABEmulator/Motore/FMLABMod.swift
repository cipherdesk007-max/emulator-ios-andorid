// FMLAB Emulator: pacchetti grafici (mod) della PSP. PPSSPP sostituisce le texture originali con quelle di un
// pacchetto HD fatto dalla comunità (texture ridisegnate, a volte in 4K): la grafica sembra rifatta.
// I pacchetti si mettono in File › FMLAB Emulator › Giochi › Mod › PSP › <codice del gioco> (es. ULES01234), con
// dentro textures.ini e le immagini, come li distribuiscono gli autori. FMLAB non scarica né include pacchetti.
// Il core li cerca nella "memory stick" (PSP/TEXTURES): lì si mette un collegamento alla cartella Mod.
import Foundation

enum FMLABMod {
    static var cartellaPSP: URL { FMLABEmulatore.cartellaGiochi().appendingPathComponent("Mod/PSP", isDirectory: true) }

    /// Crea Mod/PSP (visibile nell'app File) e i collegamenti dove PPSSPP cerca le texture.
    static func prepara() {
        let fm = FileManager.default, mod = cartellaPSP
        try? fm.createDirectory(at: mod, withIntermediateDirectories: true)
        let leggimi = mod.appendingPathComponent("LEGGIMI - README.txt")
        if !fm.fileExists(atPath: leggimi.path) {
            try? """
            FMLAB Emulator · Pacchetti grafici PSP / PSP texture packs

            IT  Ogni pacchetto va in una cartella col codice del gioco (es. ULES01234), con dentro textures.ini e le
                immagini. Il codice lo vedi nel menu del gioco › Pacchetti grafici. FMLAB non scarica né include pacchetti.
            EN  Each pack goes in a folder named with the game code (e.g. ULES01234), containing textures.ini and the
                images. The code is in the game menu › Texture Packs. FMLAB does not download or include packs.
            """.write(to: leggimi, atomically: true, encoding: .utf8)
        }
        let sistema = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FMLAB/Sistema", isDirectory: true)
        for base in [FMLABEmulatore.cartellaSalvataggi(), sistema, sistema.appendingPathComponent("PPSSPP")] {
            let t = base.appendingPathComponent("PSP/TEXTURES")
            if let dove = try? fm.destinationOfSymbolicLink(atPath: t.path), dove == mod.path { continue }
            try? fm.createDirectory(at: t.deletingLastPathComponent(), withIntermediateDirectories: true)
            var dir: ObjCBool = false
            if fm.fileExists(atPath: t.path, isDirectory: &dir) {
                // c'era una cartella vera (pacchetti messi a mano): si spostano in Mod/PSP, poi il collegamento
                for f in (try? fm.contentsOfDirectory(atPath: t.path)) ?? [] { try? fm.moveItem(at: t.appendingPathComponent(f), to: mod.appendingPathComponent(f)) }
                try? fm.removeItem(at: t)
            }
            try? fm.createSymbolicLink(at: t, withDestinationURL: mod)
        }
    }
    /// Il pacchetto di un gioco: codice, cartella e se c'è (textures.ini o immagini dentro).
    static func stato(_ gioco: URL) -> (codice: String, cartella: URL, presente: Bool)? {
        guard let c = FMLABPSP.leggi(gioco)?.codice, !c.isEmpty else { return nil }
        let d = cartellaPSP.appendingPathComponent(c, isDirectory: true)
        let pieno = !((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []).isEmpty
        return (c, d, pieno)
    }
}
