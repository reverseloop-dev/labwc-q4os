// labwc-q4os battery HUD - nuova scheda (pagina interna dell'addon)
(() => {
  "use strict";
  const api = (typeof browser !== "undefined") ? browser : chrome;
  const HINT = "clicca o Ctrl+Alt+B per nascondere";
  let hidden = false;

  function fmtMinutes(min) {
    const n = Math.round(Number(min));
    if (!isFinite(n) || n <= 0) { return ""; }
    const h = Math.floor(n / 60);
    const m = n % 60;
    return h <= 0 ? m + "m" : h + "h " + String(m).padStart(2, "0") + "m";
  }

  function build() {
    let host = document.getElementById("lbqc-ext-host");
    if (host) { return host; }
    host = document.createElement("div");
    host.id = "lbqc-ext-host";
    host.setAttribute("popover", "manual");
    host.style.cssText = "position:fixed;inset:auto;left:0;bottom:0;width:0;height:0;" +
      "margin:0;padding:0;border:0;background:transparent;overflow:visible;";
    document.body.appendChild(host);
    try { host.showPopover(); } catch (e) { /* noop */ }
    const root = host.attachShadow({ mode: "open" });
    const style = document.createElement("style");
    style.textContent = `
      :host { all: initial; }
      #hud {
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
      #hud.hidden { transform: translateX(-102%); opacity: 0; pointer-events: none; }
      #tab {
        position: fixed; left: 0; bottom: 18px; z-index: 2147483647;
        width: 22px; height: 44px; box-sizing: border-box;
        display: flex; align-items: center; justify-content: center;
        border-radius: 0 10px 10px 0; background: rgba(15, 23, 42, 0.92);
        border: 1px solid rgba(148, 163, 184, 0.45); border-left: 0;
        color: #e2e8f0; cursor: pointer; user-select: none;
        pointer-events: auto; opacity: 0; transform: translateX(-10px);
        transition: opacity .25s ease, transform .25s ease;
      }
      #tab.visible { opacity: 1; transform: translateX(0); }
      #batt { position: relative; width: 34px; height: 16px; border: 2px solid currentColor; border-radius: 4px; box-sizing: border-box; }
      #batt::after { content: ""; position: absolute; right: -5px; top: 4px; width: 3px; height: 6px; border-radius: 0 2px 2px 0; background: currentColor; }
      #fill { position: absolute; left: 1px; top: 1px; bottom: 1px; width: 60%; border-radius: 1px; background: #4ade80; transition: width .4s ease, background-color .4s ease; }
      #fill.low { background: #f87171; }
      #fill.mid { background: #fbbf24; }
      #est { color: #cbd5e1; font-size: 12px; font-weight: 600; }
      #state { color: #94a3b8; font-size: 12px; font-weight: 500; }
      #hint { color: #94a3b8; font-size: 11px; font-weight: 500; border-left: 1px solid rgba(148,163,184,.35); padding-left: 9px; }
    `;
    const box = document.createElement("div");
    box.id = "hud";
    box.title = "Clicca per nascondere";
    box.innerHTML = '<div id="batt"><div id="fill"></div></div>' +
      '<span id="pct">--%</span><span id="est"></span><span id="state"></span>' +
      '<span id="hint">' + HINT + "</span>";
    const tab = document.createElement("div");
    tab.id = "tab";
    tab.title = "Mostra batteria";
    tab.innerHTML = '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2">' +
      '<rect x="2" y="7" width="16" height="10" rx="2"></rect>' +
      '<rect x="19" y="10" width="2" height="4" rx="1" fill="currentColor" stroke="none"></rect>' +
      '<rect id="tabfill" x="4.5" y="9" width="8" height="6" rx="1" fill="currentColor" stroke="none"></rect></svg>';
    root.appendChild(style);
    root.appendChild(box);
    root.appendChild(tab);
    box.addEventListener("click", () => setHidden(true));
    tab.addEventListener("click", () => setHidden(false));
    return host;
  }

  function apply() {
    const host = build();
    const root = host.shadowRoot;
    root.getElementById("hud").classList.toggle("hidden", hidden);
    root.getElementById("tab").classList.toggle("visible", hidden);
  }

  function setHidden(value) {
    hidden = !!value;
    apply();
    try { api.storage.local.set({ lbqcHudHidden: hidden }); } catch (e) { /* noop */ }
    if (!hidden) { refresh(); }
  }

  function render(data) {
    const root = build().shadowRoot;
    const pctEl = root.getElementById("pct");
    const estEl = root.getElementById("est");
    const stateEl = root.getElementById("state");
    const fill = root.getElementById("fill");
    const tabFill = root.getElementById("tabfill");
    const pct = Number(data && data.pct);
    if (data && data.error) {
      pctEl.textContent = "n/d"; fill.style.width = "0%";
      estEl.textContent = ""; stateEl.textContent = "batteria non disponibile";
      return;
    }
    if (!isFinite(pct) || pct < 0) {
      pctEl.textContent = "AC"; fill.style.width = "100%"; fill.className = "";
      estEl.textContent = ""; stateEl.textContent = (data && data.source) || "rete";
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
    try {
      api.runtime.sendMessage({ type: "lbqc-battery" }, (reply) => {
        if (api.runtime.lastError || !reply) {
          render({ error: "native" });
          return;
        }
        render(reply);
      });
    } catch (e) {
      render({ error: "native" });
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
    setHidden(!hidden);
  }, true);

  try {
    api.storage.local.get({ lbqcHudHidden: false }, (stored) => {
      hidden = !!(stored && stored.lbqcHudHidden);
      apply();
      refresh();
      setInterval(refresh, 15000);
    });
  } catch (e) {
    apply();
    refresh();
    setInterval(refresh, 15000);
  }
})();
