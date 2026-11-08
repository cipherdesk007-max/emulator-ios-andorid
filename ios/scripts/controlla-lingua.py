#!/usr/bin/env python3
"""FMLAB Emulator: elenca le stringhe dell'interfaccia (Text, Label, LF, Toggle, Button, ...) che non hanno la traduzione italiana."""
import re, sys, pathlib
qui = pathlib.Path(__file__).resolve().parent.parent / "FMLABEmulator"
tradotte = set()
for riga in (qui / "it.lproj/Localizable.strings").read_text(encoding="utf-8").splitlines():
    m = re.match(r'^"((?:[^"\\]|\\.)*)"\s*=', riga)
    if m: tradotte.add(m.group(1))
dinamici = re.compile(r'\b(?:titolo|spiega|nome): "((?:[^"\\]|\\.)*)"')
modello = re.compile(r'\b(?:Text|Label|LF|Toggle|Button|Picker|Section|NavigationLink|TextField|navigationTitle)\(\s*"((?:[^"\\]|\\.)*)"')
mancano = set()
for f in qui.rglob("*.swift"):
    testo = f.read_text(encoding="utf-8")
    for m in list(modello.finditer(testo)) + list(dinamici.finditer(testo)):
        k = m.group(1)
        if "\\(" in k or not re.search(r"[A-Za-z]", k): continue
        if k not in tradotte: mancano.add(k)
for k in sorted(mancano): print(k)
print(f"{len(mancano)} senza traduzione", file=sys.stderr)
sys.exit(1 if "--controlla" in sys.argv and mancano else 0)
