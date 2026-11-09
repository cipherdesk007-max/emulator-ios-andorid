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
    "azahar": ("Nintendo 3DS (Azahar)", ["3ds", "3dsx", "cci", "cxi", "app", "elf"], "Consigliato per il 3DS · telefoni potenti"),
    "citra": ("Nintendo 3DS (Citra, vecchio)", ["3ds", "3dsx", "cci", "cxi"], "Telefoni potenti"),
    "dolphin": ("GameCube / Wii", ["iso", "gcm", "rvz", "wbfs", "ciso"], "Telefoni potenti"),
}

# file di sistema che alcuni core vogliono nella cartella di sistema (font, dati): dal buildbot di libretro
SISTEMA = {"ppsspp": "PPSSPP.zip", "dolphin": "Dolphin.zip"}
BASE_SISTEMA = "https://buildbot.libretro.com/assets/system/"

def scarica(u):
    r = urllib.request.Request(u, headers={"User-Agent": "FMLAB-Emulator-CI"})
    with urllib.request.urlopen(r, timeout=180) as f:
        return f.read()

# core pubblicati dai loro autori su GitHub invece che sul buildbot
GITHUB = {"azahar": "azahar-emu/azahar"}

def dagithub(repo):
    """L'ultima versione stabile con un core libretro per Android arm64 tra i file allegati."""
    r = urllib.request.Request(f"https://api.github.com/repos/{repo}/releases?per_page=15", headers={"User-Agent": "FMLAB-Emulator-CI", "Accept": "application/vnd.github+json"})
    if os.environ.get("GH_TOKEN"): r.add_header("Authorization", "Bearer " + os.environ["GH_TOKEN"])
    rel = json.load(urllib.request.urlopen(r, timeout=60))
    for v in sorted(rel, key=lambda x: (x.get("prerelease", True), x.get("published_at") or ""), reverse=False):
        pass
    for v in [x for x in rel if not x.get("prerelease")] + [x for x in rel if x.get("prerelease")]:
        nomi = [a["name"] for a in v.get("assets", [])]
        for a in v.get("assets", []):
            n = a["name"].lower()
            if "libretro" in n and "android" in n and (n.endswith(".zip") or n.endswith(".so")):
                print(f"    {repo} {v['tag_name']}: {a['name']}")
                return scarica(a["browser_download_url"])
        print(f"    {repo} {v['tag_name']}: nessun core Android tra {nomi[:12]}")
    raise RuntimeError("nessun core Android nelle release")

def libreria(dati):
    """La .so dentro uno zip (anche zip dentro zip), oppure i dati stessi se sono già una .so."""
    if dati[:4] == b"\x7fELF": return dati
    z = zipfile.ZipFile(io.BytesIO(dati))
    so = [n for n in z.namelist() if n.endswith(".so") and "android" in n.lower() or n.endswith("_libretro_android.so")] or [n for n in z.namelist() if n.endswith(".so")]
    if so: return z.read(sorted(so, key=lambda n: ("arm64" not in n and "aarch64" not in n, n))[0])
    for n in z.namelist():
        if n.endswith(".zip"): return libreria(z.read(n))
    raise RuntimeError("nessuna .so")

def main(out):
    elenco = []
    for nome, (console, est, nota) in CORE.items():
        file = f"{nome}_libretro_android.so.zip"
        try:
            dati = dagithub(GITHUB[nome]) if nome in GITHUB else scarica(BASE + file)
        except Exception as e:
            print(f"--  {nome}: non disponibile ({e})"); continue
        try:
            lib = libreria(dati)
        except Exception as e:
            print(f"!!  {nome}: zip non valido ({e})"); continue
        if lib[:4] != b"\x7fELF" or lib[18] != 0xB7 or b"retro_run" not in lib:   # ELF, AArch64, libretro
            print(f"!!  {nome}: non è un core arm64"); continue
        uscita = f"{nome}.so.zip"
        with zipfile.ZipFile(os.path.join(out, uscita), "w", zipfile.ZIP_DEFLATED) as z2:
            z2.writestr(f"lib{nome}_libretro.so", lib)
        b = open(os.path.join(out, uscita), "rb").read()
        voce = {"nome": nome, "console": console, "estensioni": est, "nota": nota, "file": uscita,
                "sha256": hashlib.sha256(b).hexdigest(), "misura": len(b), "misuraLibreria": len(lib)}
        if nome in SISTEMA:
            try:
                sz = scarica(BASE_SISTEMA + SISTEMA[nome]); zipfile.ZipFile(io.BytesIO(sz)).testzip()
                fs = f"sistema-{nome}.zip"; open(os.path.join(out, fs), "wb").write(sz)
                voce.update({"sistema": fs, "sistemaSha256": hashlib.sha256(sz).hexdigest(), "sistemaMisura": len(sz)})
                print(f"    + file di sistema {SISTEMA[nome]}: {len(sz) // 1024} KB")
            except Exception as e:
                print(f"    ! file di sistema {nome}: {e}")
        elenco.append(voce)
        print(f"ok  {nome}: {len(lib) // 1024} KB")
    json.dump({"schema": 1, "data": datetime.date.today().isoformat(), "fonte": BASE, "core": elenco},
              open(os.path.join(out, "core-android.json"), "w"), indent=1, ensure_ascii=False)
    if not elenco: sys.exit("nessun core scaricato")

main(sys.argv[1])
