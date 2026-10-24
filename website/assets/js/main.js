/* Ostsicht – kleine Helfer: Kopfzeile, Jahr, Anfrage per E-Mail vorbereiten */
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

  var EMPFAENGER = "info@ostsicht.ch";
  var status = document.getElementById("formular-status");
  var kopieren = document.getElementById("kopieren");
  var letzteNachricht = "";

  var pruefungen = {
    name: function (w) { return w.trim().length >= 2 ? "" : "Bitte geben Sie Ihren Namen an."; },
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
    return erstesFeld;
  }

  function zeigeStatus(text, ok) {
    status.textContent = text;
    status.className = "formular__status " + (ok ? "formular__status--ok" : "formular__status--fehler");
  }

  function wert(name) {
    var feld = formular.elements[name];
    return feld ? feld.value.trim() : "";
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

    var objekt = wert("objekt");
    var betreff = "Anfrage über ostsicht.ch – " + wert("name") + (objekt ? " (" + objekt + ")" : "");
    var zeilen = [
      wert("nachricht"),
      "",
      "Name: " + wert("name"),
      "Firma: " + (wert("firma") || "–"),
      "E-Mail: " + (wert("email") || "–"),
      "Telefon: " + (wert("telefon") || "–"),
      "Ort: " + (wert("ort") || "–"),
      "Objekt: " + (objekt || "–")
    ];
    letzteNachricht = "An: " + EMPFAENGER + "\nBetreff: " + betreff + "\n\n" + zeilen.join("\n");

    window.location.href = "mailto:" + EMPFAENGER +
      "?subject=" + encodeURIComponent(betreff) +
      "&body=" + encodeURIComponent(zeilen.join("\r\n"));

    zeigeStatus("Ihr E-Mail-Programm sollte sich jetzt öffnen. Falls nicht, kopieren Sie die Nachricht und senden Sie sie an " + EMPFAENGER + ".", true);
    if (kopieren && navigator.clipboard) kopieren.hidden = false;
  });

  if (kopieren) {
    kopieren.addEventListener("click", function () {
      navigator.clipboard.writeText(letzteNachricht).then(function () {
        zeigeStatus("Nachricht kopiert. Fügen Sie sie in eine E-Mail an " + EMPFAENGER + " ein.", true);
      }, function () {
        zeigeStatus("Kopieren war nicht möglich. Bitte schreiben Sie direkt an " + EMPFAENGER + ".", false);
      });
    });
  }
})();
