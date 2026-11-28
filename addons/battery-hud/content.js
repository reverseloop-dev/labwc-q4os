// labwc-q4os battery HUD - content script (Firefox/Chromium)
// Mostra batteria, carica e durata stimata dentro la pagina. Il dato arriva
// dal native host "labwc_q4os_battery" tramite il background.
(() => {
  "use strict";
  if (window.__lbqcExtBattery) { return; }
  window.__lbqcExtBattery = true;
  try {
    if (document.documentElement) {
      document.documentElement.setAttribute("data-lbqc-ext", "1");
    }
  } catch (e) { /* documento non ancora pronto */ }

  const api = (typeof browser !== "undefined") ? browser : chrome;
  const isBro = (typeof browser !== "undefined");
  const HINT = "clicca o Ctrl+Alt+B per nascondere";
  let last = null;
  let hidden = false;

  function applyHidden() {
    const host = build();
    if (!host) { return; }
    const root = host.shadowRoot;
    root.getElementById("lbqc-ext-hud").classList.toggle("lbqc-hidden", hidden);
    root.getElementById("lbqc-ext-tab").classList.toggle("lbqc-visible", hidden);
  }
  let timer = null;

  function fmtMinutes(min) {
    const n = Math.round(Number(min));
    if (!isFinite(n) || n <= 0) { return ""; }
    const h = Math.floor(n / 60);
    const m = n % 60;
    if (h <= 0) { return m + "m"; }
    return h + "h " + String(m).padStart(2, "0") + "m";
  }

  function build() {
    if (!document.documentElement) { return null; }
    document.documentElement.setAttribute("data-lbqc-ext", "1");
    let host = document.getElementById("lbqc-ext-host");
    if (!host) {
      host = document.createElement("div");
      host.id = "lbqc-ext-host";
      host.setAttribute("data-lbqc", "battery");
      // Top layer: sopra video fullscreen e UI della pagina.
      host.setAttribute("popover", "manual");
      host.style.cssText = "position:fixed;inset:auto;left:0;bottom:0;width:0;height:0;" +
        "margin:0;padding:0;border:0;background:transparent;overflow:visible;";
      document.documentElement.appendChild(host);
      try { host.showPopover(); } catch (e) { /* browser senza popover */ }
      try {
        document.addEventListener("fullscreenchange", () => {
          try { host.hidePopover(); host.showPopover(); } catch (e) { /* noop */ }
        });
      } catch (e) { /* noop */ }
    }
    let root = host.shadowRoot;
    if (!root) { root = host.attachShadow({ mode: "open" }); }
    if (!root.getElementById("lbqc-ext-hud")) {
      const style = document.createElement("style");
      style.textContent = `
        :host { all: initial; }
        #lbqc-ext-hud {
          position: fixed; left: 0; bottom: 18px; z-index: 2147483647;
          display: flex; align-items: center; gap: 10px;
          padding: 9px 16px 9px 18px; border-radius: 0 999px 999px 0;
          background: rgba(15, 23, 42, 0.86);
          border: 1px solid rgba(148, 163, 184, 0.45); border-left: 0;
          color: #e2e8f0; font: 600 15px/1.1 system-ui, sans-serif;
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
          pointer-events: auto; cursor: pointer; user-select: none;
          transform: translateX(0); opacity: 1;
          transition: transform .35s cubic-bezier(.4,0,.2,1), opacity .35s ease;
        }
        #lbqc-ext-hud.lbqc-hidden { transform: translateX(-102%); opacity: 0; pointer-events: none; }
        #lbqc-ext-tab {
          position: fixed; left: 0; bottom: 18px; z-index: 2147483647;
          width: 22px; height: 44px; box-sizing: border-box;
          display: flex; align-items: center; justify-content: center;
          border-radius: 0 10px 10px 0; background: rgba(15, 23, 42, 0.92);
          border: 1px solid rgba(148, 163, 184, 0.45); border-left: 0;
          color: #e2e8f0; cursor: pointer; user-select: none;
          pointer-events: auto; opacity: 0; transform: translateX(-10px);
          transition: opacity .25s ease, transform .25s ease;
        }
        #lbqc-ext-tab.lbqc-visible { opacity: 1; transform: translateX(0); }
        #lbqc-ext-batt { position: relative; width: 34px; height: 16px; border: 2px solid currentColor; border-radius: 4px; box-sizing: border-box; }
        #lbqc-ext-batt::after { content: ""; position: absolute; right: -5px; top: 4px; width: 3px; height: 6px; border-radius: 0 2px 2px 0; background: currentColor; }
        #lbqc-ext-fill { position: absolute; left: 1px; top: 1px; bottom: 1px; width: 60%; border-radius: 1px; background: #4ade80; transition: width .4s ease, background-color .4s ease; }
        #lbqc-ext-fill.low { background: #f87171; }
        #lbqc-ext-fill.mid { background: #fbbf24; }
        #lbqc-ext-est { color: #cbd5e1; font-size: 12px; font-weight: 600; }
        #lbqc-ext-state { color: #94a3b8; font-size: 12px; font-weight: 500; }
        #lbqc-ext-hint { color: #94a3b8; font-size: 11px; font-weight: 500; border-left: 1px solid rgba(148,163,184,.35); padding-left: 9px; }
      `;
      const box = document.createElement("div");
      box.id = "lbqc-ext-hud";
      box.title = "Clicca per nascondere";
      box.innerHTML = '<div id="lbqc-ext-batt"><div id="lbqc-ext-fill"></div></div>' +
        '<span id="lbqc-ext-pct">--%</span><span id="lbqc-ext-est"></span>' +
        '<span id="lbqc-ext-state"></span><span id="lbqc-ext-hint">' + HINT + "</span>";
      const tab = document.createElement("div");
      tab.id = "lbqc-ext-tab";
      tab.title = "Mostra batteria";
      tab.innerHTML = '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2">' +
        '<rect x="2" y="7" width="16" height="10" rx="2"></rect>' +
        '<rect x="19" y="10" width="2" height="4" rx="1" fill="currentColor" stroke="none"></rect>' +
        '<rect id="lbqc-ext-tab-fill" x="4.5" y="9" width="8" height="6" rx="1" fill="currentColor" stroke="none"></rect></svg>';
      root.appendChild(style);
      root.appendChild(box);
      root.appendChild(tab);
      box.addEventListener("click", () => setHidden(true));
      tab.addEventListener("click", () => setHidden(false));
    }
    return host;
  }

  function setHidden(value) {
    hidden = !!value;
    applyHidden();
    try {
      if (isBro) { api.storage.local.set({ lbqcHudHidden: hidden }).catch(() => {}); }
      else { api.storage.local.set({ lbqcHudHidden: hidden }); }
    } catch (e) { /* noop */ }
    if (!hidden) { refresh(); }
  }

  function toggle() {
    const host = build();
    if (!host) { return; }
    setHidden(!hidden);
  }

  function render(data) {
    const host = build();
    if (!host) { return; }
    const root = host.shadowRoot;
    const pctEl = root.getElementById("lbqc-ext-pct");
    const estEl = root.getElementById("lbqc-ext-est");
    const stateEl = root.getElementById("lbqc-ext-state");
    const fill = root.getElementById("lbqc-ext-fill");
    const tabFill = root.getElementById("lbqc-ext-tab-fill");
    const pct = Number(data && data.pct);
    if (data && data.error) {
      pctEl.textContent = "n/d";
      fill.style.width = "0%";
      estEl.textContent = "";
      stateEl.textContent = "batteria non disponibile";
      tabFill.setAttribute("width", "0");
      return;
    }
    if (!isFinite(pct) || pct < 0) {
      pctEl.textContent = "AC";
      fill.style.width = "100%";
      fill.className = "";
      estEl.textContent = "";
      stateEl.textContent = data && data.source ? String(data.source) : "rete";
      tabFill.setAttribute("width", "12");
      return;
    }
    const v = Math.max(0, Math.min(100, Math.round(pct)));
    pctEl.textContent = v + "%";
    fill.style.width = Math.max(4, v) + "%";
    fill.className = v <= 15 ? "low" : (v <= 35 ? "mid" : "");
    tabFill.setAttribute("width", String(Math.max(1.5, 10 * v / 100)));
    const charging = !!(data && data.charging);
    const mins = charging ? Number(data && data.minutesToFull) : Number(data && data.minutesLeft);
    const est = fmtMinutes(mins);
    estEl.textContent = est ? (charging ? "≈ " + est + " al pieno" : "≈ " + est) : "";
    stateEl.textContent = charging ? "in carica" : "";
  }

  function refresh() {
    const done = (reply) => {
      if (!reply || reply.error) {
        last = null;
        render({ error: "native" });
        return;
      }
      last = reply;
      render(reply);
    };
    try {
      if (isBro) {
        api.runtime.sendMessage({ type: "lbqc-battery" })
          .then(done)
          .catch(() => done(null));
      } else {
        api.runtime.sendMessage({ type: "lbqc-battery" }, (reply) => {
          done(api.runtime.lastError ? null : reply);
        });
      }
    } catch (e) {
      done(null);
    }
  }

  window.addEventListener("keydown", (event) => {
    if (event.metaKey) { return; }
    const key = (event.key || "").toLowerCase();
    const altB = event.ctrlKey && event.altKey && !event.shiftKey &&
      (key === "b" || event.code === "KeyB");
    const shiftDot = event.ctrlKey && !event.altKey && event.shiftKey &&
      (key === ">" || key === "." || event.code === "Period");
    const plainDot = event.ctrlKey && !event.altKey && !event.shiftKey &&
      (key === "." || event.code === "Period");
    if (!altB && !shiftDot && !plainDot) { return; }
    event.preventDefault();
    event.stopPropagation();
    toggle();
  }, true);

  function start() {
    // Fino alla lettura dello stato salvato resta chiuso: evita il flash del
    // HUD su una pagina dove l'utente lo aveva nascosto.
    hidden = true;
    build();
    applyHidden();
    try {
      if (isBro) {
        api.storage.local.get({ lbqcHudHidden: false })
          .then((stored) => {
            hidden = !!(stored && stored.lbqcHudHidden);
            applyHidden();
          })
          .catch(() => { hidden = false; applyHidden(); });
      } else {
        api.storage.local.get({ lbqcHudHidden: false }, (stored) => {
          hidden = !!(stored && stored.lbqcHudHidden);
          applyHidden();
        });
      }
    } catch (e) {
      hidden = false;
      applyHidden();
    }
    refresh();
    if (timer) { clearInterval(timer); }
    timer = setInterval(refresh, 15000);
  }

  try {
    api.storage.onChanged.addListener((changes, area) => {
      if (area !== "local" || !changes || !changes.lbqcHudHidden) { return; }
      hidden = !!changes.lbqcHudHidden.newValue;
      applyHidden();
    });
  } catch (e) { /* storage.onChanged non disponibile */ }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
