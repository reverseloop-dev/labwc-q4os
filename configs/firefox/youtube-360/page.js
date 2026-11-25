/* YouTube 360p: usa l'API del player per limitare la qualità.
   "medium" corrisponde a 360p; se il video non la offre, YouTube sceglie
   la qualità disponibile più vicina. Non tocca audio né impostazioni utente. */
(() => {
  "use strict";
  const QUALITY = "medium";

  // Preferenza persistente letta da YouTube al caricamento del player.
  try {
    localStorage.setItem(
      "yt-player-quality",
      JSON.stringify({
        data: QUALITY,
        creation: Date.now(),
        expiration: Date.now() + 2592000000,
      }),
    );
  } catch (_error) {
    /* localStorage può essere disabilitato */
  }

  function setQuality() {
    const player = document.getElementById("movie_player");
    if (!player) return;
    try {
      if (typeof player.setPlaybackQualityRange === "function") {
        player.setPlaybackQualityRange(QUALITY);
      } else if (typeof player.setPlaybackQuality === "function") {
        player.setPlaybackQuality(QUALITY);
      }
    } catch (_error) {
      /* player non pronto: riprova al prossimo evento */
    }
  }

  function schedule() {
    setTimeout(setQuality, 400);
    setTimeout(setQuality, 1500);
  }

  document.addEventListener("yt-navigate-finish", schedule, true);
  document.addEventListener("yt-page-data-updated", schedule, true);
  window.addEventListener("load", schedule, { once: true });

  let attempts = 0;
  const timer = setInterval(() => {
    setQuality();
    attempts += 1;
    if (attempts >= 8) clearInterval(timer);
  }, 1000);
})();
