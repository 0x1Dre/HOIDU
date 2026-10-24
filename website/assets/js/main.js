/* Ostsicht – kleine Helfer: Kopfzeile, Jahr, Kontaktformular */
(function () {
  "use strict";

  // Kopfzeile bekommt beim Scrollen eine feine Linie
  var kopf = document.getElementById("kopf");
  if (kopf) {
    var aktualisieren = function () { kopf.classList.toggle("ist-gescrollt", window.scrollY > 8); };
    window.addEventListener("scroll", aktualisieren, { passive: true });
    aktualisieren();
  }

  var jahr = document.getElementById("jahr");
  if (jahr) jahr.textContent = String(new Date().getFullYear());

  var formular = document.getElementById("formular");
  if (!formular) return;

  var status = document.getElementById("formular-status");
  var knopf = formular.querySelector("button[type=submit]");
  var gestartet = document.getElementById("gestartet");
  if (gestartet) gestartet.value = String(Math.floor(Date.now() / 1000));

  // Rückmeldung nach Versand ohne JavaScript (contact.php leitet mit ?anfrage=… zurück)
  var parameter = new URLSearchParams(window.location.search);
  if (parameter.get("anfrage") === "gesendet") zeigeStatus("Danke! Ihre Anfrage ist bei uns angekommen. Wir melden uns in der Regel innert zwei Arbeitstagen.", true);
  if (parameter.get("anfrage") === "fehler") zeigeStatus("Die Anfrage konnte nicht gesendet werden. Bitte schreiben Sie uns direkt an info@ostsicht.ch.", false);

  var pruefungen = {
    name: function (w) { return w.trim().length >= 2 ? "" : "Bitte geben Sie Ihren Namen an."; },
    email: function (w) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(w.trim()) ? "" : "Bitte geben Sie eine gültige E-Mail-Adresse an, z. B. name@firma.ch."; },
    nachricht: function (w) { return w.trim().length >= 10 ? "" : "Bitte beschreiben Sie in ein paar Worten, worum es geht."; }
  };

  function setzeFehler(feld, text) {
    var ausgabe = document.getElementById(feld.id + "-fehler");
    feld.setAttribute("aria-invalid", text ? "true" : "false");
    if (ausgabe) {
      ausgabe.textContent = text;
      ausgabe.hidden = !text;
      if (text) feld.setAttribute("aria-describedby", ausgabe.id); else feld.removeAttribute("aria-describedby");
    }
  }

  function pruefe() {
    var erstesFeld = null;
    Object.keys(pruefungen).forEach(function (name) {
      var feld = formular.elements[name];
      var text = pruefungen[name](feld.value);
      setzeFehler(feld, text);
      if (text && !erstesFeld) erstesFeld = feld;
    });
    var einwilligung = formular.elements.einwilligung;
    var text = einwilligung.checked ? "" : "Bitte bestätigen Sie die Einwilligung.";
    setzeFehler(einwilligung, text);
    if (text && !erstesFeld) erstesFeld = einwilligung;
    return erstesFeld;
  }

  function zeigeStatus(text, ok) {
    status.textContent = text;
    status.className = "formular__status " + (ok ? "formular__status--ok" : "formular__status--fehler");
  }

  // Fehler verschwinden, sobald ein Feld korrigiert ist
  Object.keys(pruefungen).forEach(function (name) {
    var feld = formular.elements[name];
    feld.addEventListener("input", function () {
      if (feld.getAttribute("aria-invalid") === "true") setzeFehler(feld, pruefungen[name](feld.value));
    });
  });

  formular.addEventListener("submit", function (ereignis) {
    ereignis.preventDefault();
    var fehlerFeld = pruefe();
    if (fehlerFeld) {
      fehlerFeld.focus();
      zeigeStatus("Bitte prüfen Sie die markierten Felder.", false);
      return;
    }

    knopf.disabled = true;
    zeigeStatus("Anfrage wird gesendet …", true);

    fetch(formular.action, {
      method: "POST",
      // Als einfaches Formular senden (kein multipart): der Server nimmt nichts anderes an.
      body: new URLSearchParams(new FormData(formular)),
      headers: { "Accept": "application/json" }
    })
      .then(function (antwort) { return antwort.json().catch(function () { return { ok: false }; }); })
      .then(function (daten) {
        if (daten && daten.ok) {
          formular.reset();
          if (gestartet) gestartet.value = String(Math.floor(Date.now() / 1000));
          zeigeStatus("Danke! Ihre Anfrage ist bei uns angekommen. Wir melden uns in der Regel innert zwei Arbeitstagen.", true);
        } else {
          zeigeStatus((daten && daten.message) || "Die Anfrage konnte nicht gesendet werden. Bitte schreiben Sie uns direkt an info@ostsicht.ch.", false);
        }
      })
      .catch(function () {
        zeigeStatus("Keine Verbindung zum Server. Bitte versuchen Sie es nochmals oder schreiben Sie an info@ostsicht.ch.", false);
      })
      .finally(function () { knopf.disabled = false; });
  });
})();
