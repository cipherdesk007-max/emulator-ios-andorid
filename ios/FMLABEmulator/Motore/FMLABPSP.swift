// FMLAB Emulator: icona (ICON0.PNG) e titolo (PARAM.SFO) dei giochi PSP, letti dal file del gioco come fa la PSP:
//  - .iso: disco ISO 9660, file PSP_GAME/ICON0.PNG e PSP_GAME/PARAM.SFO
//  - .cso: lo stesso disco compresso a blocchi da 2 KB (CISO v1, deflate grezzo)
//  - .pbp: EBOOT dei giochi scaricati, che ha icona e dati in testa
// Si legge solo quel che serve (qualche decina di KB), non il disco intero.
import Foundation
import UIKit
import Compression

enum FMLABPSP {
    struct Dati { let icona: UIImage?; let titolo: String? }

    static func leggi(_ url: URL) -> Dati? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        func pezzo(_ da: UInt64, _ n: Int) -> Data? { try? h.seek(toOffset: da); let d = h.readData(ofLength: n); return d.count == n ? d : nil }
        guard let magia = pezzo(0, 4) else { return nil }
        if magia == Data([0, 0x50, 0x42, 0x50]) { return pbp(pezzo) }                   // "\0PBP"
        let settore: (UInt32) -> Data?
        if magia == Data("CISO".utf8) {
            guard let testa = pezzo(0, 24) else { return nil }
            let totale = testa.u64(8), blocco = testa.u32(16), allinea = UInt64(testa[21])
            guard blocco == 2048, totale > 0, totale < 1 << 34 else { return nil }
            let blocchi = UInt32(totale / 2048)
            settore = { n in
                guard n < blocchi, let ind = pezzo(24 + UInt64(n) * 4, 8) else { return nil }
                let a = ind.u32(0), b = ind.u32(4)
                let inizio = UInt64(a & 0x7FFF_FFFF) << allinea, fine = UInt64(b & 0x7FFF_FFFF) << allinea
                guard fine > inizio, fine - inizio <= 4096, let grezzo = pezzo(inizio, Int(fine - inizio)) else { return nil }
                if a & 0x8000_0000 != 0 { return grezzo.prefix(2048) }                  // blocco non compresso
                return gonfia(grezzo, 2048)
            }
        } else {
            settore = { n in pezzo(UInt64(n) * 2048, 2048) }
        }
        return iso(settore)
    }

    // MARK: ISO 9660
    private static func iso(_ settore: (UInt32) -> Data?) -> Dati? {
        guard let pvd = settore(16), pvd.count >= 190, pvd[0] == 1, pvd.subdata(in: 1..<6) == Data("CD001".utf8) else { return nil }
        let radice = pvd.subdata(in: 156..<190)
        func voci(_ lba: UInt32, _ dim: UInt32) -> [(String, UInt32, UInt32, Bool)] {
            var fuori: [(String, UInt32, UInt32, Bool)] = []
            let n = min(16, (dim + 2047) / 2048)
            for k in 0..<n {
                guard let d = settore(lba + k) else { break }
                var i = 0
                while i < d.count {
                    let l = Int(d[i]); if l == 0 { break }
                    guard i + l <= d.count, l >= 34 else { break }
                    let r = d.subdata(in: (d.startIndex + i)..<(d.startIndex + i + l))
                    let ln = Int(r[32]); let nome = ln > 0 && 33 + ln <= r.count ? String(decoding: r.subdata(in: 33..<(33 + ln)), as: UTF8.self) : ""
                    fuori.append((nome.uppercased().components(separatedBy: ";")[0], r.u32(2), r.u32(10), r[25] & 2 != 0))
                    i += l
                }
            }
            return fuori
        }
        func file(_ lba: UInt32, _ dim: UInt32, max: UInt32) -> Data? {
            guard dim > 0, dim <= max else { return nil }
            var d = Data(); var k: UInt32 = 0
            while d.count < Int(dim) { guard let s = settore(lba + k) else { return nil }; d.append(s); k += 1 }
            return d.prefix(Int(dim))
        }
        guard let pg = voci(radice.u32(2), radice.u32(10)).first(where: { $0.0 == "PSP_GAME" && $0.3 }) else { return nil }
        let dentro = voci(pg.1, pg.2)
        let icona = dentro.first { $0.0 == "ICON0.PNG" }.flatMap { file($0.1, $0.2, max: 512 * 1024) }.flatMap(UIImage.init(data:))
        let titolo = dentro.first { $0.0 == "PARAM.SFO" }.flatMap { file($0.1, $0.2, max: 64 * 1024) }.flatMap(sfo)
        return icona == nil && titolo == nil ? nil : Dati(icona: icona, titolo: titolo)
    }

    // MARK: EBOOT.PBP
    private static func pbp(_ pezzo: (UInt64, Int) -> Data?) -> Dati? {
        guard let t = pezzo(0, 40) else { return nil }
        let o = (0..<8).map { UInt64(t.u32(8 + $0 * 4)) }
        func tra(_ a: Int, max: UInt64) -> Data? { let n = o[a + 1] > o[a] ? o[a + 1] - o[a] : 0; return n > 0 && n <= max ? pezzo(o[a], Int(n)) : nil }
        let titolo = tra(0, max: 64 * 1024).flatMap(sfo)
        let icona = tra(1, max: 512 * 1024).flatMap(UIImage.init(data:))
        return icona == nil && titolo == nil ? nil : Dati(icona: icona, titolo: titolo)
    }

    /// PARAM.SFO: tabella chiave → valore; serve TITLE.
    private static func sfo(_ d: Data) -> String? {
        guard d.count > 20, d.prefix(4) == Data([0, 0x50, 0x53, 0x46]) else { return nil }
        let chiavi = Int(d.u32(8)), valori = Int(d.u32(12)), n = Int(d.u32(16))
        for i in 0..<min(n, 64) {
            let e = 20 + i * 16; guard e + 16 <= d.count else { break }
            let ko = chiavi + Int(d.u16(e)), lunghezza = Int(d.u32(e + 4)), vo = valori + Int(d.u32(e + 12))
            guard ko < d.count, let fine = d[ko...].firstIndex(of: 0) else { continue }
            if String(decoding: d[ko..<fine], as: UTF8.self) == "TITLE", vo + lunghezza <= d.count {
                let t = String(decoding: d[vo..<(vo + lunghezza)].prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
        }
        return nil
    }

    /// Deflate grezzo (senza intestazione zlib), come lo scrivono i CSO.
    private static func gonfia(_ d: Data, _ attesi: Int) -> Data? {
        var fuori = Data(count: attesi)
        let n = fuori.withUnsafeMutableBytes { f in d.withUnsafeBytes { s in
            compression_decode_buffer(f.bindMemory(to: UInt8.self).baseAddress!, attesi, s.bindMemory(to: UInt8.self).baseAddress!, d.count, nil, COMPRESSION_ZLIB)
        } }
        return n == attesi ? fuori : nil
    }
}

private extension Data {
    func u16(_ i: Int) -> UInt16 { UInt16(self[startIndex + i]) | UInt16(self[startIndex + i + 1]) << 8 }
    func u32(_ i: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(self[startIndex + i + $1]) << (8 * $1) } }
    func u64(_ i: Int) -> UInt64 { UInt64(u32(i)) | UInt64(u32(i + 4)) << 32 }
}
