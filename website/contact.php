<?php
/**
 * Ostsicht – Kontaktformular
 *
 * Nimmt die Anfrage entgegen, prüft sie und sendet sie per E-Mail.
 * Antwortet mit JSON (Versand per JavaScript) oder leitet zurück auf die Seite (ohne JavaScript).
 *
 * Voraussetzung: PHP 7.4+ und ein auf dem Server eingerichteter Mailversand (sendmail/Postfix
 * oder Hosting-Mailer). Siehe README.md.
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

$gesendet = mail(
    EMPFAENGER,
    '=?UTF-8?B?' . base64_encode($betreff) . '?=',
    $text,
    implode("\r\n", $kopf),
    '-f' . ABSENDER
);

if (!$gesendet) {
    error_log('Ostsicht Kontaktformular: mail() fehlgeschlagen');
    antworten(false, 'Die Anfrage konnte gerade nicht gesendet werden. Bitte schreiben Sie uns direkt an ' . EMPFAENGER . '.', 500, $alsJson);
}

$zeiten[] = $jetzt;
@file_put_contents($datei, json_encode($zeiten), LOCK_EX);

antworten(true, 'Danke! Ihre Anfrage ist bei uns angekommen.', 200, $alsJson);
