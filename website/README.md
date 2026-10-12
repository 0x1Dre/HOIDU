# ostsicht.ch – Website

Einseitige Website für Ostsicht mit Kontaktformular. Reines HTML/CSS/JavaScript, ein kleines PHP-Skript für den Formularversand. Keine Cookies, kein Tracking, keine externen Dienste; Schriften liegen lokal.

## Dateien

```
index.html          Startseite
impressum.html      Impressum (Platzhalter ergänzen!)
datenschutz.html    Datenschutzerklärung (Platzhalter ergänzen!)
contact.php         Versand des Kontaktformulars per E-Mail
assets/css/         Stylesheet nach Ostsicht-CI
assets/js/          Formularprüfung und Versand
assets/fonts/       Barlow (WOFF, SIL Open Font License)
assets/img/         Favicon und App-Icon
.htaccess           Apache: HTTPS, Sicherheits-Header, Caching
nginx.conf.example  Gleiches für Nginx
```

## Vor dem Aufschalten anpassen

1. **Impressum und Datenschutz:** Alle orange hinterlegten Stellen ersetzen (Adresse, Rechtsform, UID, Hoster, Löschfristen, Stand). Danach die Klasse `platzhalter` entfernen.
2. **E-Mail-Adressen** in `contact.php` oben prüfen:
   - `EMPFAENGER` – Postfach, in dem Anfragen ankommen (Standard `info@ostsicht.ch`).
   - `ABSENDER` – Absender der Formular-Mails, muss zur Domain gehören (z. B. `website@ostsicht.ch`).
3. **Telefonnummer** auf Wunsch in `index.html` im Kontaktbereich (`kontakt__daten`) und im Fuss ergänzen, z. B. `<a href="tel:+41710000000">071 000 00 00</a>`.

## Aufschalten

### Hostinger (hPanel)
1. **Domain verbinden:** Websites → Website hinzufügen → ostsicht.ch. Wurde die Domain nicht bei Hostinger gekauft, beim Registrar die Nameserver auf `ns1.dns-parking.com` / `ns2.dns-parking.com` umstellen (oder die in hPanel angezeigten Werte).
2. **Postfach anlegen:** E-Mails → Verwalten → Neues Konto erstellen → `info@ostsicht.ch` mit Passwort.
3. **Dateien hochladen:** Dateien → Dateimanager → `public_html` öffnen → `ostsicht-website.zip` hochladen → Rechtsklick → Entpacken. Danach `ostsicht-website.zip`, `README.md` und `nginx.conf.example` in `public_html` löschen. `.htaccess` muss mit drin sein (versteckte Dateien im Dateimanager einblenden).
4. **SMTP-Zugang:** Eine Ebene **über** `public_html` (im Home-Verzeichnis, nicht im Web-Ordner) die Datei `ostsicht-mail.php` anlegen:
   ```php
   <?php
   return [
       'host'   => 'smtp.hostinger.com',
       'port'   => 465,
       'secure' => 'ssl',
       'user'   => 'info@ostsicht.ch',
       'pass'   => 'PASSWORT-DES-POSTFACHS',
   ];
   ```
   Ohne diese Datei wird `mail()` verwendet – das klappt bei Hostinger oft nur unzuverlässig.
5. **SSL:** Sicherheit → SSL → Zertifikat für ostsicht.ch installieren, «HTTPS erzwingen» aktivieren.
6. **Mail-DNS prüfen:** E-Mails → Verwalten → DNS-Einträge: SPF, DKIM und DMARC sollten grün sein.
7. **Testen:** Formular auf https://ostsicht.ch ausfüllen; die Anfrage muss in `info@ostsicht.ch` ankommen (Webmail).

### Apache (typisch bei Shared Hosting)
Inhalt dieses Ordners ins Web-Verzeichnis kopieren (inklusive `.htaccess`). PHP muss aktiv sein.

### Nginx
Inhalt nach `/var/www/ostsicht` kopieren, `nginx.conf.example` als Vorlage für den Server-Block nehmen, PHP-FPM installieren (`apt install php-fpm`), Zertifikat mit `certbot --nginx -d ostsicht.ch -d www.ostsicht.ch` holen.

Kopieren z. B. mit:
```
rsync -av --delete --exclude README.md --exclude nginx.conf.example ./ benutzer@server:/var/www/ostsicht/
```

### DNS
- `A`-Eintrag für `ostsicht.ch` und `www.ostsicht.ch` auf die IP-Adresse des Servers.
- Für zuverlässigen Mailversand: SPF-Eintrag, der Ihren Server erlaubt, z. B. `v=spf1 a mx ~all`. Bei einem externen Mailanbieter dessen Vorgaben (SPF, DKIM, DMARC) übernehmen.

## Mailversand testen

`contact.php` verwendet die PHP-Funktion `mail()`. Dafür braucht der Server einen eingerichteten Mailversand (Postfix/sendmail oder den Mailer des Hosters). Test auf dem Server:

```
php -r "var_dump(mail('info@ostsicht.ch', 'Test', 'Test von der Website', 'From: website@ostsicht.ch'));"
```

Gibt das `bool(false)` zurück oder kommt keine Mail an, ist der Mailversand noch nicht eingerichtet. Dann SMTP verwenden: Datei `ostsicht-mail.php` wie oben bei Hostinger beschrieben eine Ebene über dem Web-Verzeichnis anlegen (Zugangsdaten des eigenen Mailanbieters; `secure` = `ssl` für Port 465 oder `tls` für Port 587). Fehler landen im PHP-Fehlerprotokoll des Hosters.

Das Formular funktioniert auch ohne JavaScript (normaler Versand mit Rückleitung auf die Seite).

## Lokal ansehen

```
php -S localhost:8080
```
und dann http://localhost:8080 öffnen. (Mailversand funktioniert lokal meist nicht – das Formular meldet dann einen Fehler.)
