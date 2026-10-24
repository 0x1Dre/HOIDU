<?php
/**
 * Ostsicht – Kontaktformular
 *
 * Nimmt die Anfrage entgegen, prüft sie und sendet sie per E-Mail.
 * Antwortet mit JSON (Versand per JavaScript) oder leitet zurück auf die Seite (ohne JavaScript).
 *
 * Versand: Liegt eine Datei «ostsicht-mail.php» mit SMTP-Zugangsdaten EINE EBENE ÜBER dem
 * Web-Verzeichnis (z. B. neben public_html), wird per SMTP gesendet (empfohlen, z. B. bei Hostinger).
 * Sonst wird die PHP-Funktion mail() verwendet. Siehe README.md.
 */

declare(strict_types=1);

// ---------- Einstellungen ----------
const EMPFAENGER = 'info@ostsicht.ch';          // hier kommen die Anfragen an
const ABSENDER   = 'website@ostsicht.ch';       // muss eine Adresse Ihrer Domain sein (SPF/DMARC)
const BETREFF    = 'Neue Anfrage über ostsicht.ch';
const MIN_SEKUNDEN = 3;                          // schneller ausgefüllt = vermutlich Bot
const MAX_PRO_STUNDE = 5;                        // Anfragen pro IP-Adresse und Stunde
// -----------------------------------

date_default_timezone_set('Europe/Zurich');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');

$alsJson = isset($_SERVER['HTTP_ACCEPT']) && strpos($_SERVER['HTTP_ACCEPT'], 'application/json') !== false;

function antworten(bool $ok, string $meldung, int $code, bool $alsJson): void
{
    if ($alsJson) {
        http_response_code($code);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => $ok, 'message' => $meldung], JSON_UNESCAPED_UNICODE);
    } else {
        header('Location: ./?anfrage=' . ($ok ? 'gesendet' : 'fehler') . '#kontakt', true, 303);
    }
    exit;
}

/** Text für die E-Mail bereinigen: Steuerzeichen raus, Länge begrenzen. */
function feld(string $name, int $max): string
{
    $wert = isset($_POST[$name]) && is_string($_POST[$name]) ? $_POST[$name] : '';
    $wert = preg_replace('/[^\P{C}\n\t]/u', '', $wert) ?? '';
    $wert = trim($wert);
    return mb_substr($wert, 0, $max);
}

/** Für Kopfzeilen: keine Zeilenumbrüche (Schutz vor Header-Injection). */
function einzeilig(string $wert): string
{
    return trim(preg_replace('/[\r\n]+/', ' ', $wert) ?? '');
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    antworten(false, 'Bitte verwenden Sie das Formular auf der Website.', 405, $alsJson);
}

// Nur einfache Formulardaten annehmen (keine Datei-Uploads, kleine Anfragen)
$typ = strtolower($_SERVER['CONTENT_TYPE'] ?? '');
if (strpos($typ, 'application/x-www-form-urlencoded') !== 0 || (int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 16384) {
    antworten(false, 'Ungültige Anfrage.', 415, $alsJson);
}

// Spamschutz 1: verstecktes Feld muss leer bleiben
if (feld('website', 200) !== '') {
    // Bots bekommen eine Erfolgsmeldung, damit sie nicht weiter probieren
    antworten(true, 'Danke!', 200, $alsJson);
}

// Spamschutz 2: Mindestzeit zum Ausfüllen
$gestartet = (int) feld('gestartet', 20);
if ($gestartet > 0 && (time() - $gestartet) < MIN_SEKUNDEN) {
    antworten(false, 'Das ging etwas schnell. Bitte senden Sie das Formular nochmals.', 429, $alsJson);
}

// Spamschutz 3: Begrenzung je IP-Adresse (Zeitstempel in einer temporären Datei, IP nur als Hash)
$ip = $_SERVER['REMOTE_ADDR'] ?? 'unbekannt';
$datei = sys_get_temp_dir() . '/ostsicht-kontakt-' . hash('sha256', $ip . __FILE__) . '.json';
$jetzt = time();
$zeiten = [];
if (is_readable($datei)) {
    $gelesen = json_decode((string) file_get_contents($datei), true);
    if (is_array($gelesen)) {
        $zeiten = array_values(array_filter($gelesen, fn($t) => is_int($t) && $t > $jetzt - 3600));
    }
}
if (count($zeiten) >= MAX_PRO_STUNDE) {
    antworten(false, 'Sie haben in kurzer Zeit mehrere Anfragen gesendet. Bitte versuchen Sie es später nochmals oder schreiben Sie an ' . EMPFAENGER . '.', 429, $alsJson);
}

// Eingaben prüfen
$name      = feld('name', 120);
$firma     = feld('firma', 120);
$email     = feld('email', 160);
$telefon   = feld('telefon', 40);
$ort       = feld('ort', 80);
$objekt    = feld('objekt', 40);
$nachricht = feld('nachricht', 4000);
$einwilligung = feld('einwilligung', 5) === 'ja';

$fehler = [];
if (mb_strlen($name) < 2) $fehler[] = 'Name fehlt.';
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) $fehler[] = 'E-Mail-Adresse ist ungültig.';
if (mb_strlen($nachricht) < 10) $fehler[] = 'Nachricht ist zu kurz.';
if (!$einwilligung) $fehler[] = 'Einwilligung fehlt.';
$erlaubteObjekte = ['', 'Gewerbe oder KMU', 'Landwirtschaft', 'Liegenschaft', 'Privat', 'Anderes'];
if (!in_array($objekt, $erlaubteObjekte, true)) $objekt = '';

if ($fehler) {
    antworten(false, 'Bitte prüfen Sie Ihre Angaben: ' . implode(' ', $fehler), 422, $alsJson);
}

// E-Mail zusammenstellen
$zeilen = [
    'Neue Anfrage über das Kontaktformular auf ostsicht.ch',
    '',
    'Name:     ' . $name,
    'Firma:    ' . ($firma ?: '–'),
    'E-Mail:   ' . $email,
    'Telefon:  ' . ($telefon ?: '–'),
    'Ort:      ' . ($ort ?: '–'),
    'Objekt:   ' . ($objekt ?: '–'),
    '',
    'Nachricht:',
    $nachricht,
    '',
    '---',
    'Gesendet am ' . date('d.m.Y \u\m H:i') . ' Uhr. Einwilligung zur Bearbeitung erteilt.',
];
$text = implode("\r\n", $zeilen);

$betreff = BETREFF . ' – ' . einzeilig($name) . ($objekt ? ' (' . $objekt . ')' : '');
$kopf = [
    'From: Ostsicht Website <' . ABSENDER . '>',
    'Reply-To: ' . '=?UTF-8?B?' . base64_encode(einzeilig($name)) . '?= <' . einzeilig($email) . '>',
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    'X-Mailer: Ostsicht-Kontaktformular',
];

$betreffKodiert = '=?UTF-8?B?' . base64_encode($betreff) . '?=';
$smtp = smtpEinstellungen();

if ($smtp !== null) {
    // Bei SMTP muss der Absender das angemeldete Postfach sein.
    $kopf[0] = 'From: Ostsicht Website <' . $smtp['user'] . '>';
    $gesendet = smtpSenden($smtp, EMPFAENGER, $betreffKodiert, $text, $kopf);
} else {
    $gesendet = mail(EMPFAENGER, $betreffKodiert, $text, implode("\r\n", $kopf), '-f' . ABSENDER);
}

if (!$gesendet) {
    error_log('Ostsicht Kontaktformular: Versand fehlgeschlagen (' . ($smtp !== null ? 'SMTP' : 'mail()') . ')');
    antworten(false, 'Die Anfrage konnte gerade nicht gesendet werden. Bitte schreiben Sie uns direkt an ' . EMPFAENGER . '.', 500, $alsJson);
}

$zeiten[] = $jetzt;
@file_put_contents($datei, json_encode($zeiten), LOCK_EX);

antworten(true, 'Danke! Ihre Anfrage ist bei uns angekommen.', 200, $alsJson);

// ---------- SMTP ----------

/** Zugangsdaten aus ../ostsicht-mail.php (ausserhalb des Web-Verzeichnisses), sonst null. */
function smtpEinstellungen(): ?array
{
    $datei = dirname(__DIR__) . '/ostsicht-mail.php';
    if (!is_readable($datei)) return null;
    $c = include $datei;
    if (!is_array($c) || empty($c['host']) || empty($c['user']) || !isset($c['pass'])) return null;
    return [
        'host'   => (string) $c['host'],
        'port'   => (int) ($c['port'] ?? 465),
        'secure' => (string) ($c['secure'] ?? 'ssl'),   // 'ssl' (Port 465) oder 'tls' (Port 587, STARTTLS)
        'user'   => (string) $c['user'],
        'pass'   => (string) $c['pass'],
    ];
}

/** Minimaler SMTP-Versand mit Anmeldung (AUTH LOGIN), SSL oder STARTTLS. */
function smtpSenden(array $c, string $an, string $betreff, string $text, array $kopf): bool
{
    $kontext = stream_context_create(['ssl' => ['verify_peer' => true, 'verify_peer_name' => true]]);
    $adresse = ($c['secure'] === 'ssl' ? 'ssl://' : 'tcp://') . $c['host'] . ':' . $c['port'];
    $verbindung = @stream_socket_client($adresse, $nr, $meldung, 15, STREAM_CLIENT_CONNECT, $kontext);
    if (!$verbindung) {
        error_log("SMTP: Verbindung zu $adresse fehlgeschlagen: $meldung");
        return false;
    }
    stream_set_timeout($verbindung, 15);

    $lesen = function () use ($verbindung): string {
        $antwort = '';
        while (($zeile = fgets($verbindung, 515)) !== false) {
            $antwort .= $zeile;
            if (strlen($zeile) < 4 || $zeile[3] === ' ') break;   // letzte Zeile einer Antwort
        }
        return $antwort;
    };
    $befehl = function (string $zeile, array $erwartet) use ($verbindung, $lesen): bool {
        if ($zeile !== '') fwrite($verbindung, $zeile . "\r\n");
        $antwort = $lesen();
        $ok = in_array((int) substr($antwort, 0, 3), $erwartet, true);
        if (!$ok) error_log('SMTP: unerwartete Antwort auf «' . (stripos($zeile, 'AUTH') === 0 || $zeile === '' ? $zeile : strtok($zeile, ' ')) . '»: ' . trim($antwort));
        return $ok;
    };

    $hostname = $_SERVER['SERVER_NAME'] ?? 'localhost';
    $ok = $befehl('', [220]) && $befehl('EHLO ' . $hostname, [250]);
    if ($ok && $c['secure'] === 'tls') {
        $ok = $befehl('STARTTLS', [220])
            && stream_socket_enable_crypto($verbindung, true, STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT | STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT)
            && $befehl('EHLO ' . $hostname, [250]);
    }
    $ok = $ok
        && $befehl('AUTH LOGIN', [334])
        && $befehl(base64_encode($c['user']), [334])
        && $befehl(base64_encode($c['pass']), [235])
        && $befehl('MAIL FROM:<' . $c['user'] . '>', [250])
        && $befehl('RCPT TO:<' . $an . '>', [250, 251])
        && $befehl('DATA', [354]);

    if ($ok) {
        $nachricht = array_merge([
            'Date: ' . date('r'),
            'To: <' . $an . '>',
            'Subject: ' . $betreff,
            'Message-ID: <' . bin2hex(random_bytes(12)) . '@' . substr(strrchr($c['user'], '@') ?: '@localhost', 1) . '>',
        ], $kopf);
        // Zeilen, die mit einem Punkt beginnen, verdoppeln (SMTP-Regel)
        $inhalt = preg_replace('/^\./m', '..', str_replace(["\r\n", "\r"], "\n", $text)) ?? $text;
        $daten = implode("\r\n", $nachricht) . "\r\n\r\n" . str_replace("\n", "\r\n", $inhalt) . "\r\n.";
        $ok = $befehl($daten, [250]);
    }
    fwrite($verbindung, "QUIT\r\n");
    fclose($verbindung);
    return $ok;
}
