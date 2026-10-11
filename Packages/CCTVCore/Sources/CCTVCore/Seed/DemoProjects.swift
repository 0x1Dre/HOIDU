import Foundation

/// Beispielprojekte zum Kennenlernen der App. Kunden und Adressen sind frei erfunden.
public enum DemoProjects {
    public static func all(referenceDate: Date = Date()) -> [ProjectRecord] {
        [einfamilienhaus(referenceDate), baeckerei(referenceDate), logistik(referenceDate)]
    }

    static func einfamilienhaus(_ date: Date) -> ProjectRecord {
        ProjectRecord(
            reference: "DEMO EFH Muster – Aussenhaut",
            surveyDate: date,
            objectType: .eigenheim,
            siteStreet: "Rebbergstrasse 12",
            sitePostalCode: "8706",
            siteCity: "Meilen",
            notes: "Kunde wünscht möglichst wenig sichtbare Kabel. Keine Überwachung der Strasse.",
            customer: CustomerRecord(company: "", contactPerson: "Familie Muster (Demo)", phone: "+41 79 000 00 01", email: "muster@example.ch"),
            areas: [
                SiteAreaRecord(
                    name: "Hauseingang", location: .aussen, purposes: [.abschreckung, .zufahrtZutritt],
                    detectionTarget: .gesicht, nightVision: .farbeNacht, audio: .gegensprechen,
                    camera: CameraRequirementRecord(quantity: 1, formFactor: .automatisch, distanceMeters: 4),
                    positions: [CameraPositionRecord(label: "Kamera 1 – Vordach Eingang", mountingHeight: "2.4 m", viewDirection: "Richtung Haustüre, leicht nach unten")],
                    notes: "Unter Vordach, Steckdose vorhanden."
                ),
                SiteAreaRecord(
                    name: "Garten und Sitzplatz", location: .aussen, purposes: [.einbruchVandalismus],
                    detectionTarget: .person, nightVision: .infrarot,
                    camera: CameraRequirementRecord(quantity: 2, distanceMeters: 12)
                )
            ],
            infrastructure: InfrastructureRecord(
                cabling: .nein, power: .ja, internet: .ja, connection: .akku, mountingAccess: .leiter, lighting: .schwach,
                neighborPropertyAffected: true
            ),
            recording: RecordingRecord(
                mode: .ereignis, retentionDays: 7, userCount: 2, access: [.smartphone],
                features: [.personenerkennung, .pushMeldungen, .zweiWegeAudio], tier: .budget
            ),
            maintenance: MaintenanceSelection(package: .basic),
            status: .erfasst,
            isDemo: true
        )
    }

    static func baeckerei(_ date: Date) -> ProjectRecord {
        ProjectRecord(
            reference: "DEMO Bäckerei Sonnenbrot – Filiale Bahnhof",
            surveyDate: date,
            objectType: .laden,
            siteStreet: "Bahnhofstrasse 5",
            sitePostalCode: "3011",
            siteCity: "Bern",
            notes: "Kasse und Hintereingang wichtig. Mitarbeitende sind informiert, Personalkommission einbeziehen.",
            customer: CustomerRecord(company: "Bäckerei Sonnenbrot AG (Demo)", contactPerson: "Frau R. Beispiel", phone: "031 000 00 02", email: "filiale@example.ch"),
            areas: [
                SiteAreaRecord(
                    name: "Verkaufsraum", location: .innen, purposes: [.diebstahlpraevention, .abschreckung],
                    detectionTarget: .person, nightVision: .infrarot,
                    camera: CameraRequirementRecord(quantity: 2, formFactor: .dome, distanceMeters: 8)
                ),
                SiteAreaRecord(
                    name: "Kasse", location: .innen, purposes: [.diebstahlpraevention],
                    detectionTarget: .kasseVorgang, nightVision: .keine,
                    camera: CameraRequirementRecord(quantity: 1, formFactor: .dome, distanceMeters: 3)
                ),
                SiteAreaRecord(
                    name: "Hintereingang Anlieferung", location: .aussen, purposes: [.einbruchVandalismus, .zufahrtZutritt],
                    detectionTarget: .gesicht, nightVision: .farbeNacht,
                    camera: CameraRequirementRecord(quantity: 1, distanceMeters: 6)
                )
            ],
            infrastructure: InfrastructureRecord(
                cabling: .teilweise, power: .ja, internet: .ja, connection: .poeLan, mountingAccess: .leiter, lighting: .gut,
                existing: [.poeSwitch], privacyReviewRequired: true, employeesAffected: true
            ),
            recording: RecordingRecord(
                mode: .dauer, retentionDays: 14, userCount: 3, access: [.smartphone, .pcBrowser],
                features: [.personenerkennung, .pushMeldungen], tier: .standard
            ),
            maintenance: MaintenanceSelection(package: .business),
            discountPercent: 5,
            status: .offeriert,
            isDemo: true
        )
    }

    static func logistik(_ date: Date) -> ProjectRecord {
        ProjectRecord(
            reference: "DEMO Logistik Rheintal – Areal Nord",
            surveyDate: date,
            objectType: .lager,
            siteStreet: "Industriestrasse 40",
            sitePostalCode: "9443",
            siteCity: "Widnau",
            notes: "Anbindung an bestehendes VMS am Hauptsitz. IT verlangt VLAN und signierte Firmware.",
            customer: CustomerRecord(company: "Logistik Rheintal GmbH (Demo)", contactPerson: "Herr M. Probst", phone: "+41 71 000 00 03", email: "it@example.ch"),
            areas: [
                SiteAreaRecord(
                    name: "Zufahrt und Tor", location: .aussen, purposes: [.zufahrtZutritt],
                    detectionTarget: .kennzeichen, nightVision: .infrarot,
                    camera: CameraRequirementRecord(quantity: 2, distanceMeters: 15)
                ),
                SiteAreaRecord(
                    name: "Laderampen", location: .aussen, purposes: [.prozesskontrolle, .diebstahlpraevention],
                    detectionTarget: .fahrzeug, nightVision: .farbeNacht,
                    camera: CameraRequirementRecord(quantity: 6, distanceMeters: 25)
                ),
                SiteAreaRecord(
                    name: "Lagerhalle", location: .innen, purposes: [.diebstahlpraevention],
                    detectionTarget: .person, nightVision: .infrarot,
                    camera: CameraRequirementRecord(quantity: 8, distanceMeters: 20)
                ),
                SiteAreaRecord(
                    name: "Fassade Rundum", location: .aussen, purposes: [.einbruchVandalismus, .fernueberwachung],
                    detectionTarget: .person, nightVision: .infrarot,
                    camera: CameraRequirementRecord(quantity: 1, formFactor: .ptz, distanceMeters: 60)
                )
            ],
            infrastructure: InfrastructureRecord(
                cabling: .teilweise, power: .ja, internet: .ja, connection: .poeLan, mountingAccess: .hebebuehne, lighting: .schwach,
                existing: [.rack, .vpn, .vlan], existingCameras: "4 analoge Kameras (werden ersetzt)",
                privacyReviewRequired: true, publicAreaAffected: true, employeesAffected: true
            ),
            recording: RecordingRecord(
                mode: .dauer, retentionDays: 30, userCount: 8, access: [.vms, .pcBrowser, .smartphone],
                features: [.personenerkennung, .fahrzeugerkennung, .kennzeichenerkennung, .ptz, .pushMeldungen],
                tier: .premium, multiSite: true, highCybersecurity: true, thirdPartyIntegration: true, framesPerSecond: 20
            ),
            maintenance: MaintenanceSelection(package: .premium),
            status: .entwurf,
            isDemo: true
        )
    }
}
