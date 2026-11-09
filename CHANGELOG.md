# FMLAB Emulator: novità

## 0.5.1
- **Controller fisici** (Backbone, Kishi, Razer, PlayStation, Xbox…):
  - Senza TV, appena colleghi un controller i tasti sullo schermo spariscono e il gioco prende tutto lo schermo,
    tranne il DS, che ha bisogno del tocco. Scollegandolo i tasti tornano.
  - Con la TV il gioco resta sulla TV e il controller comanda.
  - Ogni controller è un giocatore: il primo collegato è il giocatore 1, il secondo il giocatore 2, fino a 4. La
    luce sul controller mostra il numero.
  - La levetta sinistra è una levetta vera (analogica) per PSP e PS1, con zona morta per non derivare. Sui
    giochi 2D muove anche la croce.
  - Il tasto Home del controller (o L3 + R3 insieme) apre il menu del gioco. L3 e R3 funzionano come tasti.
  - Avviso quando un controller si collega o si scollega.

- **Gli effetti arrivano anche sulla TV**: righe del televisore a tubo e griglia LCD c'erano solo sul telefono.
  Ora si vedono anche sulla TV e cambiano subito dal menu del gioco › Immagine. Seguono le righe vere della
  console anche quando è disegnata 2× o 3×.
- **Immagine giusta per ogni console**: per i giochi 3D (PSP, PS1, DS) il menu non propone più "pixel netti" e
  "pixel art", che sul 3D non cambiano niente; restano Nessun effetto, TV, LCD, forma e qualità.
- **PSP più fluida**: *60 Hz regolari* (acceso di base). I giochi a 30 fotogrammi al secondo mostrano ogni
  fotogramma due volte a ritmo regolare, e il movimento non va più a scatti.
- **Pacchetti grafici (mod) PSP**: le texture HD fatte dalla comunità (textures.ini più le immagini) si mettono
  in File › FMLAB Emulator › Giochi › Mod › PSP › codice del gioco. Il menu del gioco › *Pacchetti grafici* dice
  il codice (letto dal disco), dove metterlo e se il pacchetto è stato trovato. FMLAB non scarica né include
  pacchetti.
- **Impostazioni più semplici**: in Impostazioni › Giochi ci sono pagine separate, ognuna con la sua icona:
  Grafica, Aspetto dei comandi, Comandi suono e salvataggi, TV, Copie dei salvataggi, Console e BIOS, Avanzate.

- **Niente più pixel a blocchi sulla TV**. Il gioco disegnato in alta risoluzione (PSP 1440×816 con la TV) si
  ingrandiva fino a 1920×1080 con il filtro "pixel netti", che trasforma ogni pixel in un quadratone. Ora
  "Pixel netti" vale solo per i giochi 2D alla risoluzione vera. Si ingrandisce liscio:
  - la PSP, sempre;
  - PS1 e DS quando sono disegnati più grandi.
  Sul telefono il rimpicciolimento è più pulito (trilineare).
- **Ogni scelta spiega cosa fa**: Qualità, Immagine, Forma, Colori del Game Boy e del NES, Suono con l'avanti
  veloce. Ogni voce apre una pagina con le opzioni e quello che cambiano (es. "Massima: PSP 1440×816, DS 768×576,
  pensata per la TV").
- **Aspetto dei comandi**: 7 temi con l'anteprima dal vivo per SNES, PlayStation, NES e GBA:
  - FMLAB;
  - Colori della console (SNES rosso/giallo/blu/verde…);
  - Vetro;
  - Neon rosso;
  - Solo contorno;
  - Sala giochi (tasti quadrati);
  - Alto contrasto.
  Più misura (anche Molto grandi), trasparenza e vibrazione.
- **Console a scelta**: in Impostazioni › Console ogni console si accende o si spegne. Spenta, i suoi giochi
  spariscono dalla lista e i file restano. Su iPhone gli emulatori sono già tutti nell'app: iOS non lascia
  aggiungere programmi dopo l'installazione.

- **Aggiornare su iPhone**: LiveContainer non installa mentre fa girare un'app (chiede di riavviarlo), quindi il
  tasto ora è *Copia il link dell'aggiornamento*, con i tre passi: chiudi l'app, LiveContainer › + › Installa
  dall'URL e incolla, conferma.
  - Il link è sempre quello dell'ultima versione.
  - Anche la sorgente di LiveContainer si copia e si incolla in LiveContainer › Sorgenti.
- Le novità della versione si vedono formattate, senza asterischi.

- **TV**: iOS decide "schermo separato o copia del telefono" solo quando parte Duplica schermo. Se la
  duplicazione era già accesa prima di aprire FMLAB (per esempio dopo FMLAB Linux), la TV copiava tutto il
  telefono.
  - Ora l'app se ne accorge e riprova da sola a chiedere lo schermo separato.
  - Se iOS non cambia idea, apre la guida con i tre passi: ferma Duplica schermo, torna su FMLAB, riavviala.
  - La guida dice lo stato vero: "La TV è pronta per il gioco" oppure "La TV sta copiando l'iPhone". Prima
    bastava una duplicazione qualsiasi per la spunta verde.
  - In fondo alla guida e in *Copia rapporto* c'è la diagnosi: accessorio iOS 27, scena TV, schermi, scene.
- Sulla TV in attesa: "In attesa del gioco…", come "in attesa del desktop" di FMLAB Linux.

- **Icone e titoli dei giochi PSP**: letti dal gioco come fa la PSP (ICON0.PNG e PARAM.SFO), da .iso, .cso
  compressi e .pbp; anche le icone dei PS1 in formato .pbp. Le icone larghe si vedono intere.
- **Grafica**:
  - *Qualità*: Originale, Migliorata o Massima. Massima vuol dire DS 3×, PSP 3×, SNES Mode 7 4×, PS1 2×.
  - *Massima sulla TV*: con la TV collegata il gioco sale da solo a Massima.
  - *Pixel art HD*: NES, Game Boy, GBA e SNES ingranditi 4× con Scale2x a ogni fotogramma, con bordi puliti
    invece degli scalini.
  - *Aspetto retrò*:
    - texture HD della PSP (xBRZ) e filtro anisotropico 16×;
    - colori veri delle portatili (GB Color, GBA);
    - scia LCD;
    - colori del Game Boy (automatici, verde classico, Pocket, Light, grigio);
    - colori del NES (naturali, console vera, Classic Mini).
- **Avanti veloce senza suono gracchiante**: di base è muto; si può scegliere *Accelerato*.
- **Turbo**: menu del gioco › *Tieni premuto o turbo*. Il tasto si preme e si rilascia da solo circa 8 volte al
  secondo, così i dialoghi vanno avanti da soli.
- Tolto il trasferimento da FMLAB Linux (fatto).

- **I giochi di FMLAB Linux arrivano da soli**. Dentro LiveContainer ogni app ha la sua cartella dati, una accanto
  all'altra: FMLAB Emulator trova quella di FMLAB Linux e alla prima apertura porta qui tutto, senza far aprire
  cartelle.
  - I giochi si spostano, quindi niente spazio doppio.
  - Si copiano: salvataggi con Riprendi, stati, copie datate, BIOS, copertine, posizioni dei tasti, grafica e nomi
    scelti. FMLAB Linux tiene i salvataggi come riserva.
  - Anche le cartelle di giochi collegate in FMLAB Linux arrivano qui: dentro LiveContainer il permesso di iOS
    vale anche qui.
  - Si può ripetere da Impostazioni › I tuoi giochi: si copia solo quello che lì è più nuovo.
- **Impostazioni in un posto solo**: nuova scheda Impostazioni, in questo ordine: app e aggiornamenti, i tuoi
  giochi, comandi e salvataggi, BIOS, grafica, TV, copie, console, dati del motore, Wi-Fi, lingua. La scheda
  Giochi ha solo i giochi.
- **Aggiornamenti dall'app**:
  - iPhone: l'app vede da sola le versioni nuove e mostra le novità. *Aggiorna adesso* passa l'IPA a
    LiveContainer (`livecontainer://install`), che installa sopra senza perdere niente. Si può anche aggiungere
    la sorgente FMLAB alle Sorgenti di LiveContainer (`apps.json` in ogni release).
  - Android: *Aggiorna* scarica l'APK e lo installa con l'installatore di Android, sopra la versione vecchia.

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
