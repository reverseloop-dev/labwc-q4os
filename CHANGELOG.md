# Changelog — labwc-q4os

Tutte le modifiche importanti del progetto. Formato ispirato a Keep a Changelog.

## [1.27.6]

- **HUD batteria in Cage visibile all'avvio** per ogni app (Firefox, Chromium,
  FreeTube): mostra carica e, accanto, `Ctrl+Shift+. per nascondere`.
- Scorciatoie del HUD: **Ctrl+Shift+.** (Ctrl+>, prevista), **Ctrl+Alt+H**
  (H = HUD) e **Ctrl+.** (alias storico). `Ctrl+B` resta escluso: in Firefox
  apre i segnalibri.
- Diagnostica: con `LABWC_CAGE_HUD_DEBUG=1` il log va in
  `~/.local/state/labwc-q4os/cage-hud.log`; il HUD annota l'ultimo tasto
  ricevuto via BiDi per capire se Firefox li consegna alla pagina.
- `validate.sh`: verifica HUD visibile, hint e le tre scorciatoie.

## [1.27.5]

- **Login: un solo logo grande e centrato**, con **2 cm di margine a sinistra
  e a destra**, stessa trasparenza (`0.05`–`0.11`). Sostituisce le quattro copie
  sparse della 1.27.4. Ridotto in altezza solo se non entra nei margini.
- **Bluetooth: la scelta dell'utente resta davvero al riavvio.** La scelta vive
  in `/var/lib/labwc-q4os/bluetooth` e una regola udev
  (`/etc/udev/rules.d/70-labwc-q4os-bluetooth.rules`) la riapplica quando
  l'adattatore compare: se l'utente l'ha spento resta spento anche quando
  l'adattatore viene enumerato tardi al boot, caso in cui il solo
  `systemd-rfkill` non bastava. Nuovo helper root `bluetooth-state`
  (`apply|show|set on|off`), `systemd-rfkill` resta come rete di sicurezza.
- `labwc-bluetooth` usa l'helper quando presente; fallback a `rfkill` diretto.
- `validate.sh`: test di `bluetooth-state` e del logo singolo con margine.

## [1.27.4]

- **Logo del login: quattro copie invece di dodici**, ognuna con dimensione e
  posizione diversa (`0.16`, `0.115`, `0.085`, `0.06` della larghezza), sempre
  senza sovrapposizioni e senza coprire card, form e orologio. Trasparenza
  invariata (`0.05`–`0.11`).
- **Pattern generato a 1920x1080** invece di 640x1080: prima l'immagine veniva
  ritagliata da `PreserveAspectCrop` con proporzioni sbagliate e i loghi
  risultavano sfocati e fuori zona. `install.sh` passa ora larghezza e altezza.
- Documentazione aggiornata: README, `help.txt` e commenti nei quattro
  `Main.qml`.
- `scripts/validate.sh`: rimosso `labwc-install-wizard` duplicato nella lista
  dei permessi eseguibili.

## [1.27.3]

- **HUD batteria anche in Firefox**: `labwc-cage-app` avvia Firefox (e
  Firefox ESR) con `--remote-debugging-port` su `127.0.0.1` e
  `labwc-cage-hud` si collega con **WebDriver BiDi** (`session.new` +
  `script.evaluate`): `Ctrl+.` mostra e nasconde il riquadro come in FreeTube.
  La sessione BiDi viene chiusa con `session.end` all'uscita, così un riavvio
  del HUD può aprirne una nuova.
- **Chromium pronto anche se non installato**: il wrapper aggiunge la porta
  DevTools a Chromium, Chrome, Brave, Edge, Vivaldi, Thorium e Opera appena
  compaiono; se il browser non c'è nessun processo parte e nulla cambia.
- **Test di regressione** in `validate.sh`: iniezione HUD verificata con stub
  di Chromium e Firefox (flag `--remote-debugging-port`, `--bidi`,
  `session.new`).

## [1.27.2]

- **Scorciatoia HUD batteria in Cage: `Ctrl+.`** (Ctrl e il punto) al posto di
  `Ctrl+B`, che in Firefox apre i segnalibri. `Ctrl+.` non è usato da Firefox,
  Chromium né FreeTube; il riquadro si mostra e si nasconde sempre con la
  stessa combinazione.
- **Firefox normale di nuovo nel menu**: le scorciatoie create dall'installer
  (`firefox.desktop`, `chromium.desktop`, FreeTube) non vengono più scambiate
  per app dell'utente. Le voci generate portano ora `X-Labwc-Q4OS=true` e il
  generatore le riconosce anche nelle installazioni precedenti grazie alla
  coppia con la voce *(cage)*: **Firefox** e **Firefox (cage)** restano
  entrambe nella categoria Internet.
- **Test di regressione** in `validate.sh`: menu con Firefox, Firefox (cage) e
  un'app utente (posizioni verificate) e controllo che la scorciatoia HUD non
  torni a `Ctrl+B`.

## [1.27.1]

- **Correzione**: `NO_RESTORE_PROMPT` è ora inizializzata a `0`. Con
  `set -u` lo script si fermava alla riga della domanda di ripristino se
  `--no-restore` non veniva passato (variabile non assegnata).
- **README**: chiusura corretta di due sezioni a tendina (non spezzano più i
  blocchi di codice); dalla sezione *Da MentisOS a labwc-q4os* in poi il
  contenuto resta sempre visibile, compresi i comandi `curl` di installazione.

## [1.27.0]

- **Login con pattern del logo**: il logo **reverseloop-dev** non è più una
  sola copia al centro ma un **pattern tono su tono** — più copie di
  dimensioni e trasparenze diverse, tinte con il colore del tema, disposte su
  una griglia con collisioni evitate: nessun logo si sovrappone, nessuno copre
  card, form o orologio. Seed fisso per tema, quindi il disegno è sempre
  identico. `scripts/generate-login-logo.py` scrive
  `logo-pattern.png` in ogni tema; `Main.qml` lo usa come sfondo.
- **Backup unico e rollback**: l'installer conserva **solo l'ultimo backup**
  (la copia precedente viene rimossa quando ne nasce una nuova, così gli
  aggiornamenti non riempiono il disco) e registra in `manifest.tsv` ogni voce
  salvata, file di sistema compresi. Nuova **prima domanda** dell'installer,
  default **No**: *Ripristinare la configurazione dall'ultimo backup?* — con
  `--restore` per il ripristino diretto (termina senza installare) e
  `--no-restore` per saltarla. I backup vecchi senza manifest restano
  ripristinabili tramite la mappa dei nomi noti.
- **README più leggibile**: struttura del repository, file installati, opzioni,
  troubleshooting, verifica e sicurezza sono ora in sezioni a tendina
  (`<details>`); restano in chiaro caratteristiche, anteprime, Cage, login e i
  comandi `curl` di installazione.

## [1.26.0]

- **Login tono su tono**: il logo **reverseloop-dev** compare al centro anche
  nelle tre schermate di login, monocromatico, tinto con il colore del tema
  (blu `#3b82f6`, rosso `#c0565b`, verde `#4d9375`) e molto trasparente, come
  negli sfondi. Nuovo `scripts/generate-login-logo.py` (Pillow): legge
  `logo_tint` da `theme.conf` e scrive `logo.png` in ogni tema; `Main.qml` dei
  tre temi e del tema legacy mostra il PNG.
- **Batteria in Cage (Ctrl+B)**: nuove `labwc-cage-app` e `labwc-cage-hud`.
  Ogni app avviata in Cage — dal menu, dai collegamenti *(cage)* o a mano —
  passa dal wrapper: per Chromium/Chrome/Brave/Edge/Vivaldi/Opera viene
  aggiunta una porta DevTools su `127.0.0.1`, per FreeTube si usa il file
  `DevToolsActivePort` già presente. `Ctrl+B` mostra in basso a sinistra un
  riquadro con batteria e percentuale (verde, ambra ≤35%, rossa ≤15%, "in
  carica" o "AC" senza batteria) e lo nasconde al secondo Ctrl+B. Il HUD si
  inietta nell'app perché Cage mostra un solo client e non ha layer-shell;
  Firefox resta senza HUD (limite tecnico documentato).

## [1.25.0]

- **Menu del tasto destro senza duplicati**: la deduplica ora usa il programma
  eseguito (anche `flatpak run ID`) e non solo il nome; le app scelte come
  preferite compaiono solo in *★ App preferite*, e le voci fisse (Terminale,
  File manager, launcher) non si ripetono nelle categorie. Le voci `.desktop`
  generate dal progetto non vengono più elencate due volte.
- **App create dall'utente** (`.desktop` in `~/.local/share/applications`):
  tutte sotto **TOOL reverseloop**, raggruppate nelle categorie già esistenti.
  Un override utente di un'app di sistema resta nella categoria normale.
- **Bluetooth spento di default**, senza perdere la scelta: soft-block `rfkill`
  solo se non c'è uno stato salvato, `systemd-rfkill` abilitato per la
  persistenza, nuovo helper `labwc-bluetooth` (`on|off|status|toggle`) in
  *TOOL reverseloop > Sistema e diagnostica*.
- **GRUB**: domanda opt-in (default No) per portare a 1 secondo l'attesa del
  menu di avvio, con backup di `/etc/default/grub`; flag `--grub-1s` /
  `--no-grub-1s`, scelta salvata in `/etc/labwc-q4os/install-options`.
- **Correzioni dalla revisione**: le app con `Terminal=true` restano nel menu
  (la firma usa l'`Exec` originale, non il wrapper `terminator`); `freetube`
  non è più classificata come app utente; le voci del progetto elencate in
  TOOL non vengono ripetute, mentre `App in Fuzzel` resta raggiungibile;
  backup di GRUB obbligatorio prima della modifica; `systemd-rfkill.socket`
  invece del servizio statico; `rfkill` con percorso assoluto per `pkexec`;
  `install-options` letto e scritto dallo stesso percorso; shellcheck pulito
  (SC2024/SC2034/SC2155, wizard Python escluso).

- **Workflow di sviluppo**: progetto inizializzato con **GitHub Spec Kit**
  (`specify init --integration opencode`): comandi `/speckit.constitution`,
  `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`,
  `/speckit.converge`, `/speckit.clarify`, `/speckit.analyze`,
  `/speckit.checklist` in `.opencode/commands/`, artefatti in `.specify/` e
  server MCP `spec-kit` (`specify mcp`) in `opencode.json`.

## [1.24.1]

- **Sfondi**: il logo **reverseloop-dev** è ora al centro dei tre wallpaper,
  monocromatico, semitrasparente e tono su tono con lo sfondo. Il generatore
  `generate-wallpapers.py` carica il logo da `configs/logo/rl-dev.png` (o
  `$SHARE/logo/rl-dev.png`) e lo ritinteggia per ogni tema; rigenerati sfondi
  e anteprime.

## [1.24.0]

- **Scala dello schermo**: due slider separati, uno per le finestre e uno per
  il menu (entrambi 0–20 con 10 = 1.0×). Il menu e i titoli delle finestre
  vengono ridimensionati in `rc.xml` e `themerc-override`, quindi anche il
  menu del tasto destro cambia; `--apply-menu` per la riga di comando.
- **Posizione della barra**: nelle Preferenze si sceglie **Alto** o **Basso**
  per Waybar e Noctalia. La scelta è immediata, salvata in
  `~/.config/labwc/bar-position` e riapplicata a login e aggiornamenti.
- **Sfondi**: tre proposte con il logo **reverseloop-dev** al centro,
  semitrasparente e tono su tono (blu, rosso, verde), in `preview/logo/`.

## [1.23.1]

- **Scala dello schermo**: slider **0–20** con **10 = 1.0×** al centro; sotto
  10 rimpicciolisce finestre e menu, sopra 10 li ingrandisce. `--apply 8`
  applica 0.8×.
- **Aggiornamenti**: la versione online viene letta dall'API GitHub invece del
  file raw della branch, che resta in cache CDN e nasconde le release appena
  pubblicate. Una nuova VERSION viene ora riconosciuta subito.
- README: **btop++** con sole sezioni CPU e memoria e confronto labwc/Noctalia
  (~801 MiB) contro cage-kiosk esclusivo (~649 MiB); indicatore batteria in una
  riga con tre posizioni e colori (rosso, blu, verde); tabella numeri aggiornata.

## [1.23.0]

- **Scala dello schermo in Rust**: nuovo `labwc-screen-scaler`, port del
  *Screen scaling* di Q4OS per labwc/Wayland. Stessa logica: DPI del monitor
  primario da `wlr-randr`, slider **0–20 con 10 = 1.0×** al centro (sotto 10
  rimpicciolisce, sopra 10 ingrandisce), opzioni avanzate con righello e
  anteprima, **Defaults/Apply/Cancel**. Applica in
  `~/.config/labwc/screen-scale.conf` e nel blocco gestito di
  `~/.config/labwc/environment`; `Defaults` chiede conferma e azzera.
  Voce in **TOOL reverseloop → Schermo e monitor** e `.desktop` dedicato.
- Installer: compila il tool con `rustc` (aggiunto solo se manca) e lo installa
  in `~/.local/bin/labwc-screen-scaler`; `screen-scale.conf` non viene più
  cancellato.
- **Indicatore batteria**: switch **Icona** accanto a **Percentuale** nelle
  Preferenze; `show_indicator=0` nasconde l'indicatore completo (icona e
  percentuale) e il cambio è immediato.
- **Scroll verticale** in tutte le app reverseloop (Preferenze, Aggiornamenti,
  ZRAM, App in Fuzzel, Schermata di login, Scala dello schermo): barra sul lato
  destro quando il contenuto non entra, dimensioni iniziali limitate all'area
  di lavoro del monitor.
- README: screenshot di **btop++** e **Firefox** in labwc con Noctalia e in
  cage-kiosk, ognuno con didascalia, più 6 mini-screenshot dell'indicatore
  batteria (rosso/blu, sinistra/centro/destra); **Correzioni recenti** ridotta
  alle ultime 7 voci con link a questo CHANGELOG; rimossa la sezione
  *Interventi per area*.

## [1.22.18]

- Menu desktop più corto: **TOOL reverseloop** ha poche voci in chiaro e
  sottomenu tematici (**App e menu**, **Cambia tema**, **Desktop 1–4**,
  **Schermo e monitor**, **Sessione**, **Sistema e diagnostica**);
  **Impostazioni** raggruppa le app in Aspetto e desktop, Schermo e hardware,
  Sistema e sessione, Altre impostazioni.
- Rimosso il tool interno **labwc-screen-scaling** (script, voce di menu,
  `.desktop` e config). Lo **Screen scaling originale di Q4OS** non viene
  aggiunto al menu: è un tool TDE/X11 e non controlla labwc/Wayland, quindi
  sarebbe una voce che non funziona. L'installer pulisce le installazioni
  precedenti.

## [1.22.17]

- Menu **TOOL reverseloop**: labwc non ha lo scroll, quindi la voce **Scala
  dimensioni dello schermo** è in cima e sempre visibile. Gli strumenti sono
  raggruppati nei sottomenu **Schermo e monitor** (screenshot) e **Sistema e
  diagnostica** (informazioni, Doctor, aggiornamenti, ZRAM) per non tagliare
  le ultime voci sui display piccoli.

## [1.22.16]

- Nuovo **indicatore batteria** in basso: trasparente, contorno con effetto
  neon, riempimento in base alla percentuale e percentuale esatta. Posizione
  (sinistra, centro, destra) e switch percentuale si scelgono dalle
  **Preferenze della scrivania** e si applicano subito; su PC senza batteria
  non compare.
- Nuova app **Scala dimensioni dello schermo** (menu TOOL reverseloop):
  monitor, scala 1.0–2.0 o libera, risoluzione, Applica, Ripristina e
  permanenza al login, tramite `wlr-randr`.
- Installer: aggiunta la dipendenza `gir1.2-gtklayershell-0.1` per
  l'indicatore; l'app di scala usa `wlr-randr`.

## [1.22.15]

- Installer: FreeTube **non viene più reinstallato** a ogni esecuzione. Se la
  versione installata è uguale o più recente di quella del repo il passo viene
  saltato (con il pin 0.23.15 non si scarica nemmeno il `.deb`); se è più
  vecchia viene aggiornata. Nessun downgrade, nemmeno con
  `FREETUBE_PIN=latest`.

## [1.22.14]

- Cage: `exit` nella console di **AVVIA CAGE** chiude definitivamente Cage e
  le app rimaste, come la X di FreeTube. `labwc-cage-help` scrive
  `cage-exit.request` e il wrapper di sessione termina l'albero di processi
  (SIGTERM, poi SIGKILL); il controllo «Cage è già attivo» ignora zombie e
  chiude i Cage orfani di sessioni precedenti.
- README: documentato che `exit` in Cage chiude Cage e le app rimaste; la X
  di FreeTube resta invariata.

## [1.22.13]

- FreeTube in Cage: **chiusura garantita**. La X non usa più solo
  `window.close()`: al click la pagina chiama un binding DevTools,
  `freetube-close-overlay` esce con codice 10 e `labwc-freetube-cage` termina
  tutto l'albero di processi (SIGTERM, attesa di 3 s, poi SIGKILL) sul gruppo
  creato da `setsid`. Cage torna quindi sempre a labwc, anche se FreeTube va
  nel tray o ignora la chiusura della finestra.
- FreeTube in Cage: la X resta **sempre in primo piano**. È in Shadow DOM
  (isolata dal CSS dell'app) e usa un popover manuale, quindi sta nel top
  layer del browser: visibile sopra player, schermo intero, menu e dialoghi.
  Un `MutationObserver` la ricrea se un re-render la rimuove e un controllo
  periodico la riporta sopra se qualcosa la copre.
- FreeTube in Cage: aggiunte le scorciatoie **Ctrl+Shift+Q** e **Alt+F4**.
- FreeTube in Cage: se i target DevTools spariscono (finestra nascosta o
  tray) la chiusura viene richiesta lo stesso; l'overlay viene riavviato se
  muore, con backoff e limite di tentativi. Log in
  `~/.local/state/labwc-q4os/freetube-cage.log`.
- `freetube-close-overlay`: lettura robusta di `DevToolsActivePort` (file
  completo, porta valida, path del browser), retry con backoff, un solo
  lettore WebSocket, gestione dei reload, `--self-test`, `--print-js`,
  `--version`.
- `validate.sh`: controlla il nuovo helper Python (sintassi, `--self-test`,
  `--help`, `--version`) e fa uno smoke test del wrapper con `freetube` e
  overlay finti.
- README: nuova sezione **Numeri del progetto** sopra la licenza, con grafico
  a colonne colorate, legenda, scheda numeri e tappe principali.

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
