/* Inietta page.js nel mondo della pagina YouTube: il content script isolato
   non può chiamare i metodi del player. */
(() => {
  const runtime = (typeof browser !== "undefined" ? browser : chrome).runtime;
  const script = document.createElement("script");
  script.src = runtime.getURL("page.js");
  script.onload = () => script.remove();
  (document.documentElement || document).appendChild(script);
})();
