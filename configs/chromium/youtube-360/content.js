/* Inietta page.js nel mondo della pagina YouTube: il content script isolato
   non può chiamare i metodi del player. */
(() => {
  const script = document.createElement("script");
  script.src = chrome.runtime.getURL("page.js");
  script.onload = () => script.remove();
  (document.documentElement || document).appendChild(script);
})();
