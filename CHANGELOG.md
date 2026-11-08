# FMLAB Emulator: novità

## 0.1.1
- **Porta qui i giochi da FMLAB Linux**, in Giochi e in Cartelle dei giochi. Scegli la cartella Giochi di FMLAB
  Linux; va bene anche la cartella dell'app o Documents. Si copiano:
  - i giochi;
  - i salvataggi, con Riprendi, gli stati e le copie datate;
  - BIOS e copertine.
  Ogni file arriva intero: si copia in un file temporaneo e poi si mette al suo posto. Le date restano quelle
  originali. Un file più nuovo qui non viene sovrascritto. Prima di copiare si controlla lo spazio. FMLAB Linux
  non viene toccato.
- **Wi-Fi sotto LiveContainer**: iOS rifiutava l'annuncio Bonjour (errore NoAuth), perché vale l'Info.plist di
  LiveContainer e non quello dell'app. Ora il telefono con il gioco ascolta lo stesso e mostra il suo indirizzo.
  Il Controller 2 (iPhone e Android) lo trova provando gli indirizzi del Wi-Fi, oltre che con Bonjour.
- **Icone delle console** disegnate da FMLAB: forme delle macchine, niente marchi.
- Controller 2 su iPhone senza il tasto dell'avanti veloce: lo decide il giocatore 1.

Prima versione: l'emulatore di FMLAB diventa un'app a sé (prima era dentro FMLAB Linux).
- **Giochi**: NES, Game Boy/Color, GBA, SNES, PlayStation, PSP, Nintendo DS, con lo stesso motore, gli stessi
  salvataggi sicuri e le stesse copertine di FMLAB Linux 0.13.1. Nessun gioco o BIOS incluso.
- **TV fatta come quella di Linux**: con Duplica schermo (AirPlay) o un cavo USB-C/HDMI la TV ha una sua finestra,
  l'unica della scena dello schermo esterno, come il desktop di FMLAB Linux. Prima il gioco apriva una seconda
  finestra sopra a quella di Linux. Ora il gioco disegna dentro la finestra della TV e il telefono diventa il
  controller. Senza un gioco aperto la TV mostra il logo. Su iOS 27 lo schermo separato si chiede all'avvio
  (accessorio di iOS 27); *Copia rapporto* nel menu del gioco dice se è registrato.
- **Controller 2 dal Wi-Fi**: un secondo telefono sullo stesso Wi-Fi (iPhone con questa app, Android con
  FMLAB Controller) apre *Controller 2*, tocca il telefono con il gioco e diventa il giocatore 2 (fino a 4).
  Per i giochi fatti per due controller sulla stessa console.
- Icona e logo nuovi.
