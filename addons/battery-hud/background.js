// labwc-q4os battery HUD - background: inoltra al native host.
const api = (typeof browser !== "undefined") ? browser : chrome;
const HOST = "labwc_q4os_battery";

function reply(sendResponse, data) {
  try { sendResponse(data); } catch (e) { /* canale chiuso */ }
}

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "lbqc-battery") { return false; }
  try {
    api.runtime.sendNativeMessage(HOST, { type: "battery" }, (data) => {
      if (api.runtime.lastError || !data) {
        reply(sendResponse, { error: "native host non disponibile" });
        return;
      }
      reply(sendResponse, data);
    });
  } catch (e) {
    reply(sendResponse, { error: String(e) });
  }
  return true; // risposta asincrona
});
