# Changelog — labwc-q4os

Tutte le modifiche importanti del progetto. Formato ispirato a Keep a Changelog.

## [1.21.0]

- **Tasti volume** mappati con `keyd` e helper `/usr/local/bin/labwc-audio-key`:
  funzionano anche in Cage.
- Voce **AVVIA CAGE** nel menu TOOL: apre la console con esempi per lanciare
  Chromium, LibreWolf, FreeTube o altre app con `labwc-cage`.
- FreeTube può usare Flatpak o l’AppImage presente nel sistema; popup a tre
  scelte Cage / Labwc / Annulla.
- Link browser normali e `(cage)` per Chromium e LibreWolf.

## [1.20.0]

- **FreeTube** da Flathub al posto di gtk-pipe-viewer, con popup a tre scelte:
  Cage a schermo intero, Labwc, Annulla. Il popup avvisa di salvare i documenti.
- **Cage**: le app vengono aperte a schermo intero e alla chiusura si torna a
  labwc, con riallineamento della barra.
- **Browser**: si possono scegliere Chromium e LibreWolf insieme; due
  collegamenti per browser, normale e **(cage)**.
- Ogni opzione della GUI ha una descrizione sopra la scelta.
- Rimosso gtk-pipe-viewer e i suoi residui; Flathub viene aggiunto se manca e
  gli aggiornamenti passano da Flatpak.

## [1.19.2]

- Rimossi i residui del vecchio **YouTube leggero** (`labwc-youtube` e la sua
  voce .desktop) anche dagli aggiornamenti esistenti.
- **gtk-pipe-viewer** resta incluso nello script, con configurazione 360p e
  massima efficienza; la voce compare nel menu applicazioni.

## [1.19.1]

- Corretto il crash del wizard alla voce “Sì” (`trinity_present` non
  inizializzata) e l’ordine di inizializzazione del riepilogo GTK.
- Aggiunto il controllo automatico del wizard nella VM di test.

## [1.19.0]

- **gtk-pipe-viewer** proposto e compilato dal sorgente GitHub pinnato 0.5.9
  (checksum), con configurazione 360p, H.264/MP4, AV1 ignorato e HFR/DASH
  disattivati.
- Reattività login: niente attese dopo `pkill` quando il processo non esiste;
  sfondi non ricopiati se identici; controllo aggiornamenti senza doppia
  richiesta di rete.
- README aggiornato con pipe-viewer e nota SMTube non mantenuto.
- Preferiti YouTube 360p e ricarica desktop finale restano invariati.

## [1.18.0]

- Nuovo **wizard GTK** colorato con il tema attivo, box arrotondati e
  pulsanti **Indietro/Avanti**; si torna fino alla prima pagina prima di
  installare. Le domande sì/no e le checkbox sono nella GUI.
- **Preferito YouTube 360p** (`https://youtube.it/`) in Chromium e LibreWolf;
  estensione locale 360p anche in LibreWolf.
- Rimosso il vecchio YouTube leggero (mpv/yt-dlp). SMTube non viene installato:
  ultima release 2021 e pacchetto non disponibile in Debian 13/Q4OS 6.
- Repository esterne mantenute: LibreWolf via `extrepo` viene riconfigurato
  anche se il browser è già presente; Noctalia resta sul suo repository APT.
- Alla fine dell'installazione viene eseguita la ricarica del desktop, così
  un'app disinstallata (es. Chromium) sparisce subito dal menu.

## [1.17.1]

- Una sola firma finale: banner ASCII di tre righe con `created by
  reverseloop-dev`; rimosso il duplicato aggiunto dal terminale di
  aggiornamento.

## [1.17.0]

- Scelta browser **Chromium / LibreWolf / nessuno**, con descrizione e
  rimozione opzionale dell'altro browser già installato. LibreWolf dal
  repository `extrepo`, estensioni Mozilla (uBlock, Privacy Badger,
  enhanced-h264ify).
- **GUI di installazione** con checkbox (browser, shell, zram, swappiness,
  touchscreen, LookSwitcher, qpdfview, YouTube); poi la shell continua.
- **RIDOTTO AD ICONA** sotto File manager: pipemenu dinamico con le finestre
  ridotte, clic per ripristinare.
- **btop** installato dallo script.
- **YouTube leggero** con GUI zenity + mpv + yt-dlp: 720p, H.264, molta meno
  RAM di Chromium. Misura: ~276 MiB contro ~1,5 GiB sulla VM.
- Chromium avviato con opzioni Wayland/decorazioni; estensione locale
  **YouTube 360p** e pulsanti finestra visibili.
- Rimossa la ricarica automatica del desktop con popup dopo il login.
- README con screenshot delle app (Preferenze, App nel menu, Aggiornamenti,
  ZRAM).

## [1.16.0]

- Aggiunta **enhanced-h264ify** alle estensioni Chromium installate da policy.
  Blocca AV1, VP9 e VP8 su YouTube: il flusso passa a H.264 (`avc1`), più
  leggero sulle macchine vecchie. I 60fps restano attivi.
- Installazione **qpdfview** proposta dall'installer, solo se manca, con flag
  `--qpdfview` / `--no-qpdfview` e opzione salvata per gli aggiornamenti.
- Test dal vivo su VM Debian 13: YouTube ha servito `avc1.4D401E` con AV1/VP9
  bloccati; `block_60fps=false`.
- README aggiornato con estensioni, verifica Codecs, lettore PDF e storia di
  MentisOS (app locali, API IA, netbook Toshiba da 10–15 euro).
- `validate.sh` controlla che `CHANGELOG.md` contenga la versione in `VERSION`.

## [1.15.0]

- Aggiornamento incrementale: il bootstrap usa una cache e scarica solo le modifiche
  (`git fetch --depth 1`), poi pulisce i file extra e verifica SHA256SUMS.
- `LABWC_Q4OS_FRESH=1` per forzare un clone pulito.
- Nuova finestra **Storico versioni** nel pannello aggiornamenti.
- Quando è disponibile una nuova versione, la finestra mostra **Cosa c'è di nuovo**.
- `CHANGELOG.md` installato e letto dall'app; storico versioni sempre consultabile.

## [1.14.1]

- Rimozione delle app preferite solo da **Gestisci app e preferite** (tasto destro sulla riga).
- Rimosso il sottomenu “Rimuovi dai preferiti” dal menu desktop.
- Aggiunto il promemoria del tasto destro nel footer dell’app.

## [1.14.0]

- Sfondi 2560×1440 pre-generati nel repository: l’installazione li copia in pochi istanti
  invece di rigenerarli (prima ~109 secondi).
- Firma ASCII `by Reverseloop-dev` a fine installazione e aggiornamento.

## [1.13.0]

- Prima domanda: modificare i parametri o aggiornare subito con le opzioni salvate.
- Aggiornamento rapido senza domande, solo password `sudo`; flag `--quick` e `--configure`.

## [1.12.3]

- Ordinamento alfabetico garantito in tutti i sottomenu, ignorando maiuscole e accenti.
- Validazione automatica dell’ordine del menu.

## [1.12.2]

- Sottomenu, categorie, preferite e strumenti ordinati alfabeticamente.

## [1.12.1]

- Il menu viene ricaricato alla chiusura delle Preferenze e dopo modifiche da App nel menu/Fuzzel.

## [1.12.0]

- Nuovo sottomenu **TOOL reverseloop** con tutti gli strumenti del progetto.

## [1.11.5]

- Cambio layout del tema di login corretto: invalidazione cache QML di SDDM.

## [1.11.0]

- Tutte le domande dell’installer all’inizio.
- Chromium installato solo se manca o se mancano gli addon, con consenso; niente reinstallazioni.

## [1.10.x]

- Login Noctalia rapido: `offline_mode`, nessun timeout DNS.
- Bluetooth mascherato se non c’è adattatore (eliminati 25 s di attesa).
- SDDM Qt6: `QtVersion=6` e drop-in `zz-labwc-q4os.conf`.
- Tastiera virtuale solo con touchscreen.
- Firma semitrasparente nelle app.

## [1.9.x]

- Bootstrap con verifica SHA256SUMS e ancora di fiducia.
- Controllo origin del repository.
- Rimozione helper root non necessario; fix permessi e quoting.

## [1.5 – 1.8]

- Shell esclusiva: Noctalia oppure Waybar + Fuzzel, con rimozione dei pacchetti dell’altra shell.
- Sfondi del progetto nella galleria Noctalia.
- Aggiornamento interattivo nel terminale.
- Doppia/una ricarica automatica dopo il login e watchdog per barra/sfondo.
- Fix `labwc -C` (directory configurazione).

## [1.0 – 1.4]

- Prima release con labwc, Waybar, Fuzzel, temi, tre login SDDM, ZRAM, Doctor e aggiornamenti.
- Touchscreen con wvkbd/lisgd.
- Chromium con uBlock Origin Lite e Privacy Badger.
