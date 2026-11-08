# Protocollo Controller 2 (FMLAB Emulator ↔ FMLAB Controller)

Il telefono con il gioco aperto è l'**host**. I controller (iPhone con FMLAB Emulator › Controller 2, oppure
Android con FMLAB Controller) sono i **clienti**. Tutto avviene sulla rete locale (stesso Wi-Fi), senza Internet.

| | |
|---|---|
| Trasporto | TCP, porta **47654**, Nagle spento (`TCP_NODELAY`) |
| Ricerca | Bonjour/mDNS, servizio **`_fmlab-pad._tcp`**, nome = nome del telefono host |
| Messaggio | `[lunghezza u8][tipo u8][dati…]`; la lunghezza conta tipo + dati (1…255) |
| Giocatori | 2, 3, 4 → porte libretro 1, 2, 3 (la 0 è il telefono host) |

## Messaggi

| Tipo | Direzione | Dati |
|---|---|---|
| `0x01` CIAO | cliente → host | versione (1), nome del telefono in UTF-8 (max 40 byte) |
| `0x02` TASTI | cliente → host | tasti `u16` little-endian (bit = `RETRO_DEVICE_ID_JOYPAD_*`: B0 Y1 Select2 Start3 Su4 Giù5 Sinistra6 Destra7 A8 X9 L10 R11 L2 12 R2 13), levetta sinistra x `i16` LE, y `i16` LE |
| `0x03` PING | entrambi | nessuno |
| `0x81` BENVENUTO | host → cliente | giocatore `u8` (0 = partita piena, poi l'host chiude), disposizione `u8` (0 NES/GB, 1 GBA, 2 SNES/DS, 3 PS1/PSP), lunghezza nome core `u8`, nome core, titolo del gioco (resto) |
| `0x82` STATO | host → cliente | come BENVENUTO, quando si apre o chiude un gioco (titolo vuoto = nessun gioco) |

## Regole

- Il cliente manda TASTI **a ogni cambio** e comunque **una volta al secondo** (battito).
- L'host stacca un cliente che tace da **5 secondi** e ne rilascia i tasti: nessun tasto resta bloccato giù.
- Alla chiusura del gioco, o quando si stacca un cliente, i suoi tasti tornano a zero.
- Un cliente lento o sparito non rallenta il gioco: i tasti arrivano su un filo a parte e si leggono a ogni fotogramma.

## Come verificarlo senza telefoni (terza persona)

```sh
# finto controller: si collega, si presenta e preme Start per mezzo secondo
python3 - <<'PY'
import socket, struct, time
s = socket.create_connection(("IP-DELL-IPHONE", 47654)); s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
m = lambda t, d=b"": bytes([len(d) + 1, t]) + d
s.sendall(m(1, b"\x01prova"));  print(s.recv(256))      # BENVENUTO: [n, 0x81, giocatore, ...]
s.sendall(m(2, struct.pack("<Hhh", 1 << 3, 0, 0))); time.sleep(0.5); s.sendall(m(2, struct.pack("<Hhh", 0, 0, 0)))
PY
```
