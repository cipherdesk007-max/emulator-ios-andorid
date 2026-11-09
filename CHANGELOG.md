# FMLAB Emulator: novità

## 0.6.4
- **Android, DS e 3DS a schermi grandi**: l'app separa da sé i due schermi (l'emulatore li dà uno sopra l'altro) e
  li dispone come vuoi; menu del gioco › *Schermi*:
  - **Automatica**: in verticale uno sopra l'altro, in orizzontale affiancati. In orizzontale ognuno è circa il
    50% più alto di prima.
  - **Uno sopra l'altro**.
  - **Affiancati**.
  - **Grande + piccolo**: lo schermo di sopra grande, quello da toccare accanto in piccolo.
  Il tocco segue lo schermo di sotto dovunque sia. Sul 3DS si usa solo la parte vera dello schermo di sotto,
  senza le bande nere. Non dipende dalle impostazioni interne di ogni emulatore.
- **Android, tasti a schermo ridisegnati**:
  - In verticale stanno tutti sotto il gioco: L e R sopra la croce, menu al centro, SELECT e START in basso.
  - In orizzontale stanno ai lati, con SELECT e START agli angoli e il menu in alto a destra, così non coprono
    più il gioco.

- **3DS con Azahar**: Azahar è l'emulatore 3DS attuale, erede di Citra e Lime3DS, e ha un core ufficiale per
  Android.
  - Ora è tra gli emulatori da installare; se ci sono tutti e due, i giochi 3DS si aprono con lui.
  - Citra resta come alternativa.
  - Giochi criptati: servono le chiavi del proprio 3DS (keys.txt o aes_keys.txt), da mettere in
    FMLAB/BIOS/azahar/sysdata. La cartella c'è già, con un LEGGIMI. FMLAB non include chiavi.
- **PSP e GameCube/Wii completi**: installando PPSSPP o Dolphin si installano anche i loro file di sistema (font,
  dati) in FMLAB/BIOS, dal buildbot di libretro con impronta controllata. Senza, alcuni giochi non mostravano le
  scritte o non partivano.
- **Giochi in .zip anche su Android**: si vedono nella lista con la console giusta e si estraggono una volta sola
  in FMLAB/Giochi/Estratti; dalla volta dopo si aprono subito.

- **Android, schermo nero con il gioco che gira** (es. 3DS):
  - Il motore pulisce lo stato grafico che i core che disegnano sulla GPU lasciano dietro (maschere di colore,
    sampler, buffer legati), quindi l'immagine non sparisce più.
  - La finestra prende il formato giusto.
  - Se dopo 8 secondi non è arrivata nessuna immagine, l'app lo dice, con il motivo probabile e gli ultimi
    messaggi dell'emulatore. Per il 3DS, quasi sempre è un gioco criptato: servono le copie decriptate.
- **Android, tocco per DS e 3DS**: un dito sull'immagine (fuori dai tasti) tocca lo schermo del gioco.
- **Android, verticale**: il gioco sta in alto e i tasti sotto, senza coprirlo; SELECT e START non escono più
  dai tasti.

- **L'iPhone fa da controller per Android**: con un gioco aperto su Android, un iPhone sullo stesso Wi-Fi apre
  FMLAB Emulator › Controller 2 e diventa il giocatore 2 (fino a 4).
  - Android si annuncia sul Wi-Fi e risponde alla ricerca come l'iPhone.
  - Avvisa quando un giocatore entra o esce.
  - Rilascia i tasti di chi si stacca o tace da 5 secondi.
- **DS sulla TV più grande**: di base gli schermi sono affiancati; su una TV 16:9 ognuno è largo metà schermo, un
  terzo in più di prima. Si può tornare a "uno sopra l'altro" dal menu del gioco › Schermi del DS sulla TV. Il
  tocco sul telefono e il puntino sulla TV seguono la disposizione scelta.
- **Copertine e icone**:
  - per i giochi compressi già estratti si leggono dal gioco vero (icone e titoli PSP dentro .zip/.7z);
  - nei nomi si tolgono "(Track 1)", "(Disc 1)" e i numeri d'elenco ("2760 - Naruto…"), così le copertine PS1
    e PSP si trovano;
  - i giochi rimasti senza copertina vengono cercati di nuovo.
- Tolto "Solo il suono su AirPlay": non serviva per i giochi.

- **Android ha gli emulatori veri**: l'APK è ora FMLAB Emulator, non solo il controller.
  - Motore nativo scritto per Android: OpenGL ES 3 (anche per gli emulatori che disegnano sulla GPU: PSP, N64,
    3DS), suono AAudio a bassa latenza, ritmo legato al suono come su iPhone, salvataggi scritti interi.
  - **Emulatori installabili uno per uno** (scheda Emulatori): ognuno si scarica dalla release `core-android` del
    progetto, presa dal buildbot ufficiale di libretro e controllata con l'impronta. Su Android, grazie al JIT, ci
    sono anche N64, Dreamcast, 3DS e GameCube/Wii, per i telefoni potenti.
  - **Giochi** da FMLAB/Giochi e da Download, divisi per console. Salvataggi in FMLAB/Salvataggi e BIOS in
    FMLAB/BIOS, cartelle che restano anche disinstallando l'app.
  - **Controller fisici**: i tasti sullo schermo spariscono, ogni controller è un giocatore, levetta analogica,
    tasto Home = menu.
  - Menu del gioco (tasto Indietro): salva e carica stato, avanti veloce (muto), immagine.
  - Impostazioni spiegate: qualità, immagine, effetto TV/LCD, forma.
  - *Controller 2* resta: il telefono Android può ancora fare da controller per un iPhone.

- **Giochi compressi estratti una volta sola**. Prima l'app teneva solo l'ultimo gioco estratto, nella cache, e
  cancellava il precedente: cambiando gioco si estraeva tutto di nuovo. Anche iOS e l'aggiornamento dei dati
  svuotavano la cache. Ora ogni archivio si estrae una sola volta in Giochi › Estratti e da lì si apre subito;
  si estrae di nuovo solo se l'archivio cambia.
- Impostazioni › Avanzate › Giochi compressi:
  - *Elimina l'archivio dopo l'estrazione*, solo per gli archivi in Giochi, mai nelle cartelle collegate;
  - lo spazio occupato dai giochi estratti;
  - *Cancella le copie estratte*.
  Un gioco il cui archivio non c'è più resta in lista.

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
