# Ostsicht – CCTV Offer Calculator CH

Native SwiftUI-App für iPad und iPhone zur Bedarfsaufnahme von Videoüberwachungsprojekten in der Schweiz – direkt vor Ort beim Kunden und **vollständig offline**. Die App führt durch die Erfassung, fotografiert die geplanten Kamerapositionen, bewertet fünf Hersteller, berechnet drei Angebotsvarianten inklusive Speicherbedarf und Wartung und erstellt Kunden- und interne PDF-Offerten.

- Kein Server, kein Backend, keine Cloud, keine Netzwerkaufrufe, keine Drittanbieter-SDKs.
- Daten verlassen das Gerät nur durch eine aktive Benutzeraktion (Teilen, Exportieren, Backup).
- Benutzeroberfläche in Deutsch (Schweiz), Beträge in CHF, MWST standardmässig 8.1 %.

## Schnellstart

Voraussetzung: Mac mit Xcode 16 oder neuer.

1. ZIP entpacken (Doppelklick auf `CCTVOfferCalculator-CH.zip`).
2. Im Ordner `CCTVOfferCalculator-CH` die Datei `CCTVOfferCalculator.xcodeproj` doppelklicken.
3. In Xcode links das Projekt wählen, dann **Target CCTVOfferCalculator › Signing & Capabilities**: unter **Team** die eigene Apple-ID wählen (zuerst unter **Xcode › Einstellungen › Accounts** hinzufügen) und die **Bundle Identifier** auf eine eigene Kennung ändern, z. B. `ch.meinefirma.cctvofferte`.
4. iPhone/iPad per Kabel verbinden, entsperren, «Vertrauen» bestätigen und auf dem Gerät den Entwicklermodus aktivieren (**Einstellungen › Datenschutz & Sicherheit › Entwicklermodus**). Oben in Xcode das Gerät als Ziel wählen.
5. **Cmd+R** drücken. Bei einer kostenlosen Apple-ID auf dem Gerät unter **Einstellungen › Allgemein › VPN und Geräteverwaltung** dem Entwickler vertrauen.

Hinweis: Das App-Target wurde in der Entwicklungsumgebung nicht mit Xcode kompiliert (nur der Rechenkern ist getestet). Falls beim ersten Build Fehlermeldungen erscheinen, diese bitte zurückmelden. Details siehe Abschnitt [Installation auf einem physischen iPad oder iPhone](#installation-auf-einem-physischen-ipad-oder-iphone).

## Funktionsumfang

| Bereich | Inhalt |
| --- | --- |
| Dashboard | Kennzahlen, Schnellstart, zuletzt bearbeitete Projekte, Hinweis auf fehlende Firmenangaben |
| Projekte | Suche, Statusfilter, Duplizieren, Löschen, JSON-Import |
| 3D-Scan | Räume (RoomPlan) und Umgebung (LiDAR) scannen, Kameras im 3D-Modell platzieren, Grundriss in der Offerte |
| Neues Projekt | Assistent in 5 Schritten mit Fortschrittsanzeige, Validierung und automatischer Entwurfssicherung |
| Preislisten | Preislisten pro Hersteller, Einkauf/Verkauf/Marge je Position, Produkte bearbeiten, Zielmarge anwenden |
| Herstellerprofile | Neutrale Profile von Eufy, Reolink, Dahua, Uniview und Axis |
| Einstellungen | Firma, Stundensätze, Anfahrtspauschale, MWST, Annahmen, Wartungspakete, Backup/Restore |

**Assistent:** 1 Kunde und Objekt · 2 Überwachungsbereiche (mit Kamerapositionen und Fotos) · 3 Infrastruktur · 4 Aufzeichnung und Funktionen · 5 Empfehlung und Kalkulation.

**Resultate pro Projekt:** Herstellerbewertung 0–100 mit Begründung und Warnungen, drei Varianten (Budget, Standard, Premium) mit Komponenten, Vergleichstabelle nach Hersteller, Einmalkosten, monatliche Wartung, Speicherrechner mit Formel, Datenschutz- und Projekthinweise.

**Export:** Kunden-PDF (ohne Einkaufspreise und Margen), internes PDF (mit Einkauf, Marge, Deckungsbeitrag, Annahmen), CSV der Offertpositionen, Projekt als JSON, Vollbackup als JSON. Teilen, Drucken, Mail und «In Dateien sichern» laufen über das Teilen-Menü von iOS.

## Projektstruktur

```
.
├── CCTVOfferCalculator.xcodeproj      Xcode-Projekt (iOS/iPadOS 17, Swift 6)
├── CCTVOfferCalculator/               App-Target (SwiftUI, SwiftData, UIKit-Brücken)
│   ├── App/                           App-Einstieg, Navigation (AppRouter)
│   ├── Persistence/                   SwiftData-Modelle, Abbildung auf Domäne, Repository, Einstellungen
│   │   └── Models/                    Customer, Project, SiteArea, CameraRequirement, CameraPosition,
│   │                                  PhotoAttachment, Product, PriceList, Calculation, MaintenancePlan, Offer
│   ├── Components/                    Design, Auswahlchips, Kamera/Mediathek, Fotomarkierung
│   ├── Features/                      Dashboard, Projekte, Assistent, Resultate, Rechner,
│   │                                  Preislisten, Herstellerprofile, Einstellungen, Export (PDF)
│   └── Resources/                     Info.plist, Datenschutz-Manifest, Assets
├── Packages/CCTVCore/                 Reiner Swift-Kern (nur Foundation) – läuft auch unter Linux
│   ├── Sources/CCTVCore/Domain        Domänentypen (Projekt, Bereich, Foto, Produkt, Einstellungen, Geld)
│   ├── Sources/CCTVCore/Services      Bewertung, Komponentenauswahl, Arbeit, Preise, Speicher, Wartung,
│   │                                  Varianten, Validierung, Warnungen
│   ├── Sources/CCTVCore/Export        PDF-Inhalt (Dokumentmodell), CSV, JSON-Austausch
│   ├── Sources/CCTVCore/Seed          Beispielpreislisten, Demo-Projekte, Herstellerprofile
│   └── Tests/CCTVCoreTests            Unit-Tests (XCTest)
└── scripts/generate_xcodeproj.py      Erzeugt das Xcode-Projekt aus der Ordnerstruktur
```

**Architektur (MVVM):** Views enthalten keine Rechenlogik. ViewModels (`@Observable`, `@MainActor`) halten Domänenobjekte aus `CCTVCore` und rufen die Services auf. Die SwiftData-Modelle im App-Target werden in `Persistence/` auf die Domänentypen abgebildet (`record` bzw. `apply(_:)`). Dadurch ist die gesamte Kalkulation ohne iOS-SDK testbar. Auch der Inhalt der PDFs wird im Kern als Dokumentmodell erzeugt (`OfferDocumentBuilder`); die App zeichnet es nur noch mit UIKit (`PDFRenderer`).

## Voraussetzungen

- macOS mit **Xcode 16 oder neuer** (Swift 6). Das Projektformat lässt sich in Xcode 15 öffnen, der Swift-6-Sprachmodus erfordert aber den Compiler aus Xcode 16.
- iPad oder iPhone mit **iOS/iPadOS 17** oder neuer.
- Für die Tests des Kerns genügt eine Swift-6-Toolchain (macOS oder Linux).

## Bauen und testen

### Kern-Tests (ohne Xcode, auch unter Linux)

```bash
swift test --package-path Packages/CCTVCore
```

Die Tests decken Herstellerbewertung, Komponentenauswahl, Arbeitsschätzung, MWST 8.1 %, Rabatt, Rappenrundung, Margen und Deckungsbeitrag, Speicher- und Wartungsrechner, Angebotsvarianten, Validierung, Kunden-/internes PDF (keine Einkaufspreise im Kunden-PDF), Fotos im PDF, CSV-Export sowie JSON-Import/-Export inklusive Fotos und Grenzfälle ab.

### App in Xcode

1. `CCTVOfferCalculator.xcodeproj` öffnen. Das lokale Paket `Packages/CCTVCore` wird automatisch eingebunden.
2. Schema **CCTVOfferCalculator** und ein iPad- oder iPhone-Ziel wählen.
3. **⌘R** startet die App, **⌘U** führt die Kern-Tests aus.

Nach dem Hinzufügen oder Entfernen von Dateien unter `CCTVOfferCalculator/` das Projekt neu erzeugen:

```bash
python3 scripts/generate_xcodeproj.py
```

## Installation auf einem physischen iPad oder iPhone

1. In Xcode unter **Einstellungen › Accounts** die eigene Apple-ID hinzufügen (eine kostenlose Apple-ID genügt für Tests; für die Verteilung im Team ist ein Apple Developer Program nötig).
2. Im Projekt das Target **CCTVOfferCalculator › Signing & Capabilities** öffnen, **Team** wählen und die **Bundle Identifier** auf eine eigene Kennung ändern (z. B. `ch.meinefirma.cctvofferte`). Die Vorgabe `ch.example.cctvoffercalculator` ist ein Platzhalter.
3. Gerät per Kabel verbinden, entsperren und «Diesem Computer vertrauen» bestätigen.
4. Auf dem Gerät den **Entwicklermodus** aktivieren: **Einstellungen › Datenschutz & Sicherheit › Entwicklermodus**, danach Neustart bestätigen.
5. Gerät in Xcode als Ziel wählen und **⌘R** drücken.
6. Bei einer kostenlosen Apple-ID: auf dem Gerät **Einstellungen › Allgemein › VPN und Geräteverwaltung** öffnen und dem Entwicklerzertifikat vertrauen. Solche Installationen sind 7 Tage gültig und müssen danach erneut aus Xcode installiert werden; die Daten bleiben dabei erhalten.

Für mehrere Geräte im Betrieb eignen sich TestFlight oder eine MDM-Verteilung (Apple Business Manager).

## Fotos der Kamerapositionen

- **Pro Bereich** gibt es Übersichtsfotos, **pro Kameraposition** beliebig viele Fotos. Jede Position hat Beschriftung (z. B. «Kamera 1 – Nordfassade»), Montagehöhe, Blickrichtung und Notiz; jedes Foto Beschriftung und Notiz.
- **Aufnahme** direkt mit der Kamera (`UIImagePickerController`) oder **Auswahl aus der Mediathek** (`PhotosPicker`, mehrere Fotos auf einmal).
- **Berechtigung:** Beim ersten Aufnehmen fragt iOS nach dem Kamerazugriff (Text in `NSCameraUsageDescription`). Wurde der Zugriff verweigert, zeigt die App eine Meldung mit dem Knopf **«Einstellungen öffnen»**. Für die Mediathek ist keine Berechtigung nötig, da `PhotosPicker` ausserhalb der App läuft.
- **Simulator / Geräte ohne Kamera:** Die App meldet «Keine Kamera verfügbar» und verweist auf die Mediathek.
- **Markierung:** Pfeil (Blickrichtung) und Kreis (Montagepunkt) direkt auf dem Foto. Markierungen werden getrennt vom Bild als relative Koordinaten gespeichert und können jederzeit entfernt werden; das Originalfoto bleibt unverändert.
- **Neu aufnehmen / ersetzen / löschen** ist pro Foto möglich (beim Ersetzen werden alte Markierungen entfernt).
- **Speicherung:** Fotos werden auf maximal 1600 Pixel Kantenlänge verkleinert, als JPEG (Qualität 72 %) komprimiert und über SwiftData mit `@Attribute(.externalStorage)` im geschützten Sandbox-Speicher der App abgelegt.
- **PDF:** Das interne PDF enthält immer alle Fotos inklusive Markierungen. Im Kunden-PDF erscheinen Fotos nur, wenn der Schalter **«Fotos im Kunden-PDF anzeigen»** aktiv ist; einzelne Fotos lassen sich pro Foto ausschliessen.
- **JSON:** Fotos werden als **Base64** im Feld `imageData` des jeweiligen Fotos eingebettet (Schalter «Fotos in JSON einbetten»). Ohne Fotos exportierte Dateien enthalten Beschriftungen und Markierungen, aber keine Bilddaten.

## Datensicherung

Alle Daten liegen ausschliesslich lokal auf dem Gerät. Es gibt drei Wege zur Sicherung:

1. **Vollbackup in der App:** **Einstellungen › Datensicherung › Vollständiges Backup erstellen**. Die JSON-Datei enthält alle Projekte inklusive Fotos, alle Preislisten und Einstellungen. Sie wird in der Dateien-App unter **Auf meinem iPad › Ostsicht › Backups** abgelegt und kann zusätzlich per AirDrop, USB-Stick, Mail oder auf einen Mac kopiert werden. Wiederherstellen über **Backup einspielen**: Projekte werden ergänzt (bereits vorhandene übersprungen), Preislisten und Einstellungen ersetzt.
2. **Einzelne Projekte:** Im Projekt unter **Export › Projekt (JSON)**. Import über **Projekte › Importieren**; existiert das Projekt bereits, wird eine Kopie angelegt.
3. **Gerätebackup:** Verschlüsseltes Backup über den Finder (Mac) bzw. iTunes (Windows) sichert die App-Daten mit. Ein iCloud-Gerätebackup sichert die App-Daten ebenfalls – wer das nicht möchte, schaltet die App unter **Einstellungen › [Name] › iCloud › iCloud-Backup** aus.

Der Assistent sichert einen begonnenen Entwurf zudem automatisch lokal, damit vor Ort erfasste Angaben und Fotos nach einem Abbruch der App erhalten bleiben.

### Format der JSON-Dateien

```json
{
  "format": "ch.cctv-offer-calculator.project",
  "schemaVersion": 1,
  "exportedAt": "2026-10-11T14:05:00.000Z",
  "appVersion": "1.0 (1)",
  "includesPhotos": true,
  "project": {
    "areas": [
      {
        "name": "Hauseingang",
        "positions": [
          {
            "label": "Kamera 1 – Nordfassade",
            "mountingHeight": "2.8 m",
            "viewDirection": "Richtung Einfahrt",
            "photos": [
              {
                "caption": "Montagepunkt",
                "imageData": "<Base64-JPEG>",
                "markers": [{ "kind": "pfeil", "startX": 0.2, "startY": 0.3, "endX": 0.6, "endY": 0.5 }],
                "includeInCustomerPDF": true
              }
            ]
          }
        ]
      }
    ]
  }
}
```

Das Vollbackup verwendet `"format": "ch.cctv-offer-calculator.backup"` mit den Feldern `projects`, `priceLists` und `settings`. Dateien neuerer Formatversionen werden mit einer klaren Meldung abgelehnt.

## 3D-Scan und Kameraplanung

Im Projekt gibt es den Reiter **3D**. Damit lassen sich Räume und Umgebung mit dem LiDAR-Sensor erfassen (iPhone Pro ab 12, iPad Pro ab 2020) und die geplanten Kameras direkt im 3D-Modell platzieren.

- **Raum scannen** (Apple RoomPlan): erkennt Wände, Türen, Fenster und Möbel. Nur in Innenräumen.
- **Umgebung scannen** (ARKit Scene Reconstruction): freies Dreiecksnetz, auch draussen, Reichweite rund 5 m.
- **Kamera setzen:** In der 3D-Ansicht auf die Wand tippen. Die Kamera schaut automatisch von der Wand weg. Blickrichtung, Neigung, Öffnungswinkel, Reichweite und Höhe sind einstellbar.
- **Verknüpfung:** Jede platzierte Kamera kann mit einer Kameraposition aus den Überwachungsbereichen verknüpft werden; beim Setzen wird die nächste freie Position vorgeschlagen.
- **Grundriss:** Beim Scannen entsteht eine Draufsicht. Kameras erscheinen darauf nummeriert mit Blickfeld – in der App und im Abschnitt «Grundriss und Kamerastandorte» der Kunden- und der internen Offerte.
- **Live-Punkte:** Beim Scannen zeigt ein grünes Punkteraster (aus der LiDAR-Tiefe) und ein Zähler, was schon erfasst ist.
- **Texturen:** Während des Scans werden bis zu 40 Aufnahmen mit Kameraposition gespeichert. Daraus werden Wände, Boden, Türen und Fenster (Raum) bzw. das Dreiecksnetz (Umgebung) eingefärbt; verdeckte Stellen werden über die Tiefe erkannt.
- **Fotos:** Bis zu 8 gut verteilte Aufnahmen werden als Fotos zum Scan übernommen und im 3D-Modell an ihrem Standort angezeigt. Eigene Fotos lassen sich ergänzen; der Scan kann einem Überwachungsbereich zugeordnet werden (Reiter «Fotos»). Fotos erscheinen im PDF beim Grundriss.
- **Speicherung:** Modell (`.scn`) und Grundriss liegen lokal in der Datenbank (`externalStorage`). Der JSON-Export ohne Fotos enthält nur die Platzierungen; das Vollbackup enthält alles.

## Gestaltung (Ostsicht CI/CD)

Die App folgt dem Ostsicht-Manual (`Design/Ostsicht/Ostsicht-CI-CD-Manual.pdf`). Die verbindlichen Logodateien liegen als SVG daneben.

| Element | Umsetzung |
| --- | --- |
| Farben | `Components/Theme.swift`: `gruen` #1B7A44 (Hauptfarbe, Buttons, Tint), `sonne` #F29A1F (nur Flächen/Akzente), `anthrazit` #22272B, `grau` #5F6368, `kalk` #F4F2EC (Hintergrund hell). Oranger Text nur über `sonneText` (#9C5600 hell, #F5B04D dunkel). Im Dunkelmodus werden Grün und Anthrazit für Text aufgehellt. |
| Schrift | Barlow Regular, Medium und SemiBold (SIL Open Font License, `Resources/Fonts`). `Font.brand(_:)` skaliert mit Dynamic Type; Titel in SemiBold, kein Bold, kein Kursiv. Navigations- und Tab-Leisten über `BrandFont.applyAppearance()`. |
| Logo | `Components/OstsichtBrand.swift` zeichnet Signet, horizontales und vertikales Logo (Standard, Negativ, Mono) als Vektor nach den SVG-Vorlagen – in der App (`OstsichtLogo`) und im PDF. |
| App | Anzeigename «Ostsicht», App-Icon = Signet auf Weiss, Logo in der Seitenleiste, Markenkopf mit Claim «Alles im Blick.» im Dashboard, Ecken 4–8 pt. |
| PDF | Logo oben links, Titel Anthrazit, Abschnittslinien und Tabellenköpfe Grün, Zebrastreifen Kalk, grüne Horizontlinie im Fuss mit Kontaktdaten aus den Firmenangaben. |

## Kalkulationsgrundlagen

- **Herstellerbewertung:** Basiswert 50 Punkte, regelbasierte Zu- und Abschläge, begrenzt auf 0–100 (`ManufacturerScoring`). Eufy bevorzugt 1–4 Akku-/WLAN-Kameras im Wohnbereich; Reolink 2–16 Kameras mit PoE und lokaler Speicherung; Dahua KMU mit PoE, NVR, Daueraufnahme und KI-Funktionen; Uniview preisbewusste, skalierbare KMU-Systeme; Axis Cybersecurity, VMS, Mehrstandort, Integration und Premium.
- **Varianten:** Je Variante wird der Hersteller mit der höchsten Summe aus Bewertung und Variantenneigung gewählt; die Wahl lässt sich pro Variante manuell übersteuern.
- **Preise:** Material und Arbeit getrennt. Zwischentotal − Rabatt = Total exkl. MWST; MWST (Standard 8.1 %) auf Rappen gerundet; Total inkl. MWST auf 5 Rappen gerundet (Rundungsdifferenz wird ausgewiesen). Marge = (Verkauf − Einkauf) ÷ Verkauf. Deckungsbeitrag = Nettoerlös nach Rabatt − Materialeinkauf − interne Arbeitskosten. Einkauf, Marge und Deckungsbeitrag erscheinen nur im internen Modus und im internen PDF.
- **Arbeit:** Begehung, Montage (je nach Montagezugang 0.75–2 h pro Kamera), Verkabelung (20 m pro Stunde), Konfiguration, Test, Dokumentation, Anfahrtspauschale. Stunden werden auf 0.25 h aufgerundet.
- **Speicher:** `Speicher [TB] = Kameras × Bitrate [kbit/s] × 1000 ÷ 8 × 3600 × Stunden pro Tag × Tage ÷ 10¹² × (1 + Reserve)`. Konservative Standardbitrate: Megapixel × Bilder pro Sekunde × 80 kbit/s (H.264) bzw. 48 kbit/s (H.265). Nutzbare Kapazität 90 % pro Disk.
- **Wartung:** Monat = Grundgebühr + Kameras × Preis pro Kamera + NVR/VMS × Preis pro Gerät (+ optionaler Vor-Ort-Check ÷ 12), auf 5 Rappen gerundet; Jahr = 12 × Monat.

## Beispieldaten

Die mitgelieferten Preislisten enthalten **Beispielpreise in CHF exkl. MWST** für typische Produkte von Eufy, Reolink, Dahua, Uniview, Axis sowie herstellerneutrales Zubehör. Sie dienen nur zur Demonstration und müssen vor der ersten Offerte mit den aktuellen Konditionen des Distributors abgeglichen werden. Die drei Demo-Projekte (Einfamilienhaus, Bäckerei, Logistikareal) verwenden frei erfundene Kunden.

## Datenschutz

- Jedes Projekt zeigt den Hinweis, dass der Kunde für Zweck, Kameraausrichtung, Informationspflicht, Bewilligungen und Aufbewahrung verantwortlich ist.
- Warnungen erscheinen, wenn öffentlicher Raum, Nachbargrundstücke, Audio oder Mitarbeitende betroffen sind, sowie bei langen Aufbewahrungsfristen.
- Das PDF enthält einen neutralen Datenschutzabschnitt. Die Hinweise ersetzen keine Rechtsberatung.
- Die App enthält ein Datenschutz-Manifest (`PrivacyInfo.xcprivacy`): kein Tracking, keine erhobenen Daten.

## Bekannte Einschränkungen

- Die Debug-Konfiguration kompiliert mit `-O`, damit die Texturberechnung beim Testen nicht minutenlang dauert. Zum schrittweisen Debuggen bei Bedarf in den Build Settings auf `-Onone` stellen.
- Das Ostsicht-Design wurde ohne Xcode umgesetzt (keine Kompilierung in der Entwicklungsumgebung). Falls beim Build Fehler auftreten, bitte zurückmelden.
