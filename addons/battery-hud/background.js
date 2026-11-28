// labwc-q4os battery HUD - background: inoltra al native host.
const api = (typeof browser !== "undefined") ? browser : chrome;
const isBro = (typeof browser !== "undefined");
const HOST = "labwc_q4os_battery";

function nativeBattery() {
  if (isBro) {
    return api.runtime.sendNativeMessage(HOST, { type: "battery" });
  }
  return new Promise((resolve, reject) => {
    api.runtime.sendNativeMessage(HOST, { type: "battery" }, (data) => {
      if (api.runtime.lastError || !data) {
        reject(new Error(api.runtime.lastError ? api.runtime.lastError.message : "no host"));
        return;
      }
      resolve(data);
    });
  });
}

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || message.type !== "lbqc-battery") { return false; }
  nativeBattery()
    .then((data) => {
      try { sendResponse(data); } catch (e) { /* canale chiuso */ }
    })
    .catch((error) => {
      try { sendResponse({ error: String(error) }); } catch (e) { /* canale chiuso */ }
    });
  return true; // risposta asincrona
});
