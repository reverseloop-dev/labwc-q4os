# Changelog — labwc-q4os

Tutte le modifiche importanti del progetto. Formato ispirato a Keep a Changelog.

## [1.22.12]

- Browser: **LibreWolf sostituito da Firefox ESR** (pacchetto Debian), con le
  stesse estensioni (uBlock Origin, Privacy Badger, enhanced-h264ify), il
  preferito YouTube 360p e la policy in `/etc/firefox-esr/policies`.
- Firefox ESR: `dom.ipc.processCount=2` e
  `browser.tabs.unloadOnLowMemory=true` per ridurre la RAM.
- Creati i collegamenti **Firefox ESR** e **Firefox ESR (cage)**; migrazione
  con rimozione delle vecchie voci e del pacchetto LibreWolf.
- Installer testuale e wizard GTK: descrizione del perché scegliere Chromium
  (compatibilità web app, più RAM) o Firefox ESR (più leggero, privacy).
- Testato su Lenovo Chromebook E300 in Cage con YouTube, Wikipedia e più schede.

## [1.22.11]

- Cage su Intel i915: aggiunti `WLR_DRM_NO_ATOMIC=1` e
  `WLR_DRM_NO_MODIFIERS=1`. Evitano i freeze con
  `Atomic commit failed: Device or resource busy` quando una pagina web
  complessa (LibreWolf, Chromium) tiene la GPU occupata.
- La correzione vale sia per l’avvio dal menu `(cage)` sia per `labwc-cage`
  lanciato manualmente da console.
- README: riformulato il paragrafo sul risparmio batteria e sull’uso in treno.

## [1.22.10]

- Installer: aggiunte le dipendenze per applicare il tema icone tramite
  GSettings su Debian minimale (`gsettings-desktop-schemas`,
  `libglib2.0-bin`, `dconf-gsettings-backend`).

## [1.22.9]

- Icone: corretto il bug per cui PCManFM mostrava le icone standard. GTK3 su
  Wayland non legge `settings.ini` per le icone: ora l’installer e il login
  impostano **GSettings** `icon-theme=labwc-q4os`; `settings.ini` resta come
  fallback.
- Icone: aggiunte al tema **cartella Home, Scrivania, Cestino**, cartelle
  Documenti/Immagini/Musica/Video/Scaricati, dischi, rete, azioni del file
  manager e tipi di file comuni. PCManFM e i dialoghi di sistema non usano più
  icone Adwaita per queste voci.
- README: avviso che **Plasma** richiede molta RAM e spazio ed è sconsigliato
  su PC datati o con poca memoria/archiviazione.

## [1.22.8]

- Touchpad: click fisico in basso a sinistra = sinistro, in basso a destra =
  destro (`clickMethod buttonAreas`); il tap a due dita resta tasto destro.
- Touchscreen: nuovo `labwc-touch-tap`. Due dita = tasto destro, tre dita =
  Esc per uscire dallo schermo intero di FreeTube/browser, anche in Cage.
  Un dito resta il click sinistro nativo.
- Installer: regola udev per `/dev/uinput` accessibile al gruppo `input`,
  pacchetto `python3-evdev`, avvio del demone tap e self-heal del marker touch.
- README: spiegazione semplice di cos’è Cage e perché viene usato, prima
  degli esempi di avvio app.

## [1.22.7]

- FreeTube: l’installer usa **0.23.15**, ultima versione senza SABR, e la
  blocca con `apt-mark hold`; disattiva il controllo aggiornamenti interno.
  Evita il loop “reloading player according to SABR request”. Verificato in
  labwc e Cage: riproduzione oltre i 60 s senza reload.
- FreeTube: il pulsante X in Cage viene chiuso insieme all’app (PID + trap);
  non può più comparire per errore nella finestra normale di labwc.
- Per l’ultima versione: `FREETUBE_PIN=latest ./install.sh` (può avere SABR).

## [1.22.6]

- Noctalia: se manca `~/.config/labwc/shell` (installazione interrotta o
  config ripristinata) viene ricavato da `/etc/labwc-q4os/install-options` e
  riscritto; Noctalia orfana di una sessione precedente viene fermata e
  riavviata. Risolve il login senza barra/launcher.
- Touchpad: due dita = tasto destro sia in tap sia in click
  (`tapButtonMap lrm`, `clickMethod clickfinger`), anche per “Elan Touchpad”.
- Cage: rimosso `WLR_RENDERER=pixman`; su Intel i915 le superfici DMABUF di
  FreeTube restavano nere. Il renderer automatico (GLES2) le compone.
- Cage: confermati `WLR_BACKENDS=drm,libinput` e gruppo `input` per mouse e
  tastiera.

## [1.22.5]

- Cage: fermato `labwc-update-check` durante Cage e impediti i duplicati a
  ogni riavvio di labwc. Libera RAM e lascia attivi solo i servizi di sessione
  necessari (PipeWire, portali, keyring, systemd utente).
- `labwc-cage`: rifiuta un secondo Cage se ce n’è già uno attivo (niente
  compositori annidati); notifiche con timeout per non bloccarsi dentro Cage.
- Documentato perché al ritorno da Cage non viene chiesta la password: la
  sessione di login resta attiva, labwc viene solo chiuso e riavviato.

## [1.22.4]

- FreeTube: il collegamento normale apre FreeTube **dentro labwc** con la X
  della finestra; non chiede più di passare da Cage.
- FreeTube (cage): aggiunto un pulsante **X in alto a destra** dentro la
  pagina, perché Cage non disegna decorazioni. La X chiude FreeTube e riporta
  a labwc.
- FreeTube: qualità video predefinita **360p** in entrambe le modalità
  (`defaultQuality` in `settings.db`).
- Installer: aggiunto `python3-websockets` per il pulsante X di FreeTube.

## [1.22.3]

- Cage: corretto il mouse che non funzionava. `WLR_BACKENDS=drm` disattivava
  il backend `libinput` di wlroots: ora è `drm,libinput`, quindi Cage apre
  davvero `/dev/input/event*`.
- Cage: l’utente viene aggiunto al gruppo `input` anche quando il touchscreen
  non è attivo (prima avveniva solo con `--touch`).
- FreeTube: aggiunto il collegamento **FreeTube (cage)** accanto a FreeTube.
- Serve un logout/login una volta per applicare gruppo `input` e wrapper.

## [1.22.2]

- FreeTube: aggiunto **repo APT dedicato** (GHaaAPT) con chiave firmata;
  gli aggiornamenti passano da `apt update && apt upgrade`.
- Cage: cursore software con tema **Adwaita** (`XCURSOR_THEME`), oltre al
  gruppo `input`, per rendere visibile e usabile il mouse.
- Nessun Flatpak/Flathub.

## [1.22.1]

- Cage: aggiunto l’utente al gruppo **input** (mouse/tastiera su DRM) e
  attivato il cursore software (`WLR_NO_HARDWARE_CURSORS=1`).
- Dopo l’aggiornamento serve un logout/login per applicare il gruppo input e
  il nuovo wrapper di sessione.
- FreeTube resta `.deb` ufficiale; nessun Flatpak.

## [1.22.0]

- **Cage reale**: `(cage)` e AVVIA CAGE chiudono davvero labwc, liberano RAM e
  avviano Cage sulla stessa sessione; alla chiusura labwc riparte da solo.
- Popup **Sì/No** con avviso esplicito: i file non salvati andranno persi.
- **AVVIA CAGE** apre una shell dentro Cage; da lì si lanciano le app
  direttamente e con `exit` si torna a labwc.
- `cage` manuale resta in shell con `labwc-return` / `Ctrl+Alt+F1`.
- FreeTube solo `.deb` ufficiale, nessun Flatpak/Flathub.
- Dopo l’aggiornamento serve un logout/login per attivare il nuovo wrapper di
  sessione; fino ad allora Cage resta annidato.

## [1.21.4]

- `labwc-cage` / collegamenti **(cage)**: alla chiusura dell’app si torna
  automaticamente a labwc.
- `cage` manuale dalla console: il wrapper stampa prima e dopo le istruzioni
  `labwc-return` / `Ctrl+Alt+F1`.
- FreeTube resta solo `.deb` ufficiale; nessun Flatpak/Flathub.

## [1.21.3]

- Nuovo comando **labwc-return**: torna al VT della sessione labwc dopo Cage;
  non lanciare `labwc` da console (DRM occupato).
- `labwc-return` e `Ctrl+Alt+F1` documentati in README e nella console Cage.
- FreeTube solo dal `.deb` ufficiale; Flatpak/Flathub rimossi.

## [1.21.2]

- Rimosso Flatpak/Flathub: FreeTube ora si installa dal **.deb ufficiale**
  0.25.3 (circa 100 MB, checksum) senza runtime Flatpak.
- L’installer elimina Flatpak/Flathub residui e non li usa più.
- Aggiornati comandi Cage e documentazione.

## [1.21.1]

- FreeTube: la domanda e il wizard dicono chiaramente che servono circa 1,5 GB
  liberi e diversi minuti di download.
- Installer: controllo spazio prima del download Flatpak, con messaggio chiaro
  se lo spazio non basta.

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
