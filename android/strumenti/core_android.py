#!/usr/bin/env python3
"""Scarica i core libretro per Android arm64 dal buildbot ufficiale, controlla che dentro ci sia una libreria ELF
arm64 con retro_run, e scrive core-android.json (nome, console, estensioni, impronta, misura) per l'app."""
import hashlib, io, json, os, sys, urllib.request, zipfile, datetime

BASE = "https://buildbot.libretro.com/nightly/android/latest/arm64-v8a/"
# core: (console, estensioni, nota)
CORE = {
    "fceumm": ("NES", ["nes", "fds", "unf", "unif"], ""),
    "gambatte": ("Game Boy / Color", ["gb", "gbc", "dmg"], ""),
    "mgba": ("Game Boy Advance", ["gba"], ""),
    "snes9x": ("Super Nintendo", ["sfc", "smc"], ""),
    "genesis_plus_gx": ("Mega Drive / Master System / Game Gear", ["md", "gen", "smd", "sms", "gg", "bin"], ""),
    "pcsx_rearmed": ("PlayStation", ["cue", "pbp", "chd", "m3u", "iso", "img", "bin"], ""),
    "melonds": ("Nintendo DS", ["nds"], "BIOS facoltativi"),
    "desmume": ("Nintendo DS (DeSmuME)", ["nds"], ""),
    "ppsspp": ("PSP", ["iso", "cso", "pbp", "chd"], ""),
    "mupen64plus_next_gles3": ("Nintendo 64", ["n64", "z64", "v64"], ""),
    "flycast": ("Dreamcast", ["cdi", "gdi", "chd"], "BIOS dc_boot.bin"),
    "citra": ("Nintendo 3DS", ["3ds", "3dsx", "cci", "cxi"], "Telefoni potenti"),
    "dolphin": ("GameCube / Wii", ["iso", "gcm", "rvz", "wbfs", "ciso"], "Telefoni potenti"),
}

def scarica(u):
    r = urllib.request.Request(u, headers={"User-Agent": "FMLAB-Emulator-CI"})
    with urllib.request.urlopen(r, timeout=180) as f:
        return f.read()

def main(out):
    elenco = []
    for nome, (console, est, nota) in CORE.items():
        file = f"{nome}_libretro_android.so.zip"
        try:
            dati = scarica(BASE + file)
        except Exception as e:
            print(f"--  {nome}: non disponibile ({e})"); continue
        try:
            z = zipfile.ZipFile(io.BytesIO(dati)); so = next(n for n in z.namelist() if n.endswith(".so")); lib = z.read(so)
        except Exception as e:
            print(f"!!  {nome}: zip non valido ({e})"); continue
        if lib[:4] != b"\x7fELF" or lib[18] != 0xB7 or b"retro_run" not in lib:   # ELF, AArch64, libretro
            print(f"!!  {nome}: non è un core arm64"); continue
        uscita = f"{nome}.so.zip"
        with zipfile.ZipFile(os.path.join(out, uscita), "w", zipfile.ZIP_DEFLATED) as z2:
            z2.writestr(f"lib{nome}_libretro.so", lib)
        b = open(os.path.join(out, uscita), "rb").read()
        elenco.append({"nome": nome, "console": console, "estensioni": est, "nota": nota, "file": uscita,
                       "sha256": hashlib.sha256(b).hexdigest(), "misura": len(b), "misuraLibreria": len(lib)})
        print(f"ok  {nome}: {len(lib) // 1024} KB")
    json.dump({"schema": 1, "data": datetime.date.today().isoformat(), "fonte": BASE, "core": elenco},
              open(os.path.join(out, "core-android.json"), "w"), indent=1, ensure_ascii=False)
    if not elenco: sys.exit("nessun core scaricato")

main(sys.argv[1])
