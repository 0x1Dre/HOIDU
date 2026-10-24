# ostsicht.ch – Website

Einseitige, rein statische Website für Ostsicht: HTML, CSS und etwas JavaScript. Kein PHP, keine Datenbank,
keine Cookies, kein Tracking, keine externen Dienste; Schriften liegen lokal.

Das Anfrageformular sendet nichts an den Server. Es stellt aus den Feldern eine E-Mail an `info@ostsicht.ch`
zusammen und öffnet sie im E-Mail-Programm der Besucherin (mailto). Wer kein E-Mail-Programm eingerichtet hat,
kann die fertige Nachricht kopieren. Ohne JavaScript übergibt der Browser das Formular direkt an das E-Mail-Programm.

## Dateien

```
index.html          Startseite
impressum.html      Impressum (Platzhalter ergänzen!)
datenschutz.html    Datenschutzerklärung (Platzhalter ergänzen!)
assets/css/         Stylesheet nach Ostsicht-CI
assets/js/          Kopfzeile, Jahr, Anfrage per E-Mail vorbereiten
assets/fonts/       Barlow (WOFF, SIL Open Font License)
assets/img/         Favicon und App-Icon
.htaccess           Apache: HTTPS, Sicherheits-Header, Caching, keine Skripte
nginx.conf.example  Gleiches für Nginx
```

## Vor dem Aufschalten anpassen

1. **Impressum und Datenschutz:** Alle orange hinterlegten Stellen ersetzen (Adresse, Rechtsform, UID, Hoster, Stand). Danach die Klasse `platzhalter` entfernen.
2. **E-Mail-Adresse:** `EMPFAENGER` in `assets/js/main.js` und `action="mailto:…"` in `index.html`.
3. **Telefonnummer** auf Wunsch in `index.html` im Kontaktbereich (`kontakt__daten`) und im Fuss ergänzen, z. B. `<a href="tel:+41710000000">071 000 00 00</a>`.

## Aufschalten

### Eigener Server mit Nginx (so läuft ostsicht.ch)
Die Website kommt per Git auf den Server (nur der Ordner `website/`):
```
cd /var/www
git clone --filter=blob:none --sparse https://github.com/0x1Dre/HOIDU.git hoidu
cd hoidu && git sparse-checkout set website
```
Server-Block nach `nginx.conf.example` (Wurzel `/var/www/hoidu/website`), Zertifikat mit
`certbot --nginx -d ostsicht.ch -d www.ostsicht.ch`. PHP wird nicht gebraucht.

Updates: `git -C /var/www/hoidu pull`

### Webhosting mit Apache (z. B. Hostinger)
Inhalt dieses Ordners ins Web-Verzeichnis (`public_html`) kopieren, inklusive `.htaccess`.

### DNS
- `A`-Eintrag für `ostsicht.ch` und `www.ostsicht.ch` auf die IP-Adresse des Servers.
- Die E-Mail-Einträge (MX, SPF, DKIM, DMARC) des Mailanbieters nicht verändern.

## Lokal ansehen

```
python3 -m http.server 8080
```
und dann http://localhost:8080 öffnen.
