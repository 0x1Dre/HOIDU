import Foundation

/// Beispielpreislisten mit realistischen CHF-Richtwerten. Es handelt sich ausdrücklich um
/// Beispieldaten: Vor der Verwendung in einer Offerte müssen Preise mit den aktuellen
/// Konditionen des Distributors abgeglichen werden.
public enum SeedCatalog {
    public static let version = 1
    public static let exampleNote = "Beispielpreise in CHF exkl. MWST – vor Verwendung mit aktuellen Distributorpreisen abgleichen."

    public static func priceLists(validFrom: Date = Date()) -> [PriceListRecord] {
        [
            PriceListRecord(manufacturer: .eufy, name: "Eufy Security – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: eufy),
            PriceListRecord(manufacturer: .reolink, name: "Reolink – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: reolink),
            PriceListRecord(manufacturer: .dahua, name: "Dahua – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: dahua),
            PriceListRecord(manufacturer: .uniview, name: "Uniview – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: uniview),
            PriceListRecord(manufacturer: .axis, name: "Axis Communications – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: axis),
            PriceListRecord(manufacturer: .neutral, name: "Zubehör und Installationsmaterial – Beispielpreise", validFrom: validFrom, note: exampleNote, isExampleData: true, products: neutral)
        ]
    }

    // MARK: - Hilfsfunktionen

    static func chf(_ francs: Int, _ rappen: Int = 0) -> Decimal {
        Money.rappen(francs * 100 + rappen)
    }

    static func camera(
        _ m: Manufacturer, _ name: String, _ article: String,
        buy: Decimal, sell: Decimal, tier: OfferTier,
        mp: Int, outdoor: Bool = true, night: NightVision = .infrarot, audio: AudioMode = .nein,
        form: CameraFormFactor, poe: Bool = true, wifi: Bool = false, battery: Bool = false,
        ptz: Bool = false, ai: Bool = true, lpr: Bool = false
    ) -> ProductRecord {
        ProductRecord(
            manufacturer: m, category: .kamera, name: name, articleNumber: article, unit: .stueck,
            purchasePrice: buy, sellPrice: sell, tier: tier,
            specs: ProductSpecs(
                megapixels: mp, isOutdoor: outdoor, nightVision: night, audio: audio, formFactor: form,
                supportsPoE: poe, supportsWiFi: wifi, isBattery: battery, isPTZ: ptz, hasAnalytics: ai, hasLPR: lpr
            )
        )
    }

    static func recorder(
        _ m: Manufacturer, _ name: String, _ article: String,
        buy: Decimal, sell: Decimal, tier: OfferTier,
        channels: Int, poePorts: Int, bays: Int, wifi: Bool = false
    ) -> ProductRecord {
        ProductRecord(
            manufacturer: m, category: .nvr, name: name, articleNumber: article, unit: .stueck,
            purchasePrice: buy, sellPrice: sell, tier: tier,
            specs: ProductSpecs(supportsPoE: poePorts > 0, supportsWiFi: wifi, channels: channels, poePorts: poePorts, driveBays: bays)
        )
    }

    static func item(
        _ m: Manufacturer, _ category: ProductCategory, _ role: ComponentRole, _ name: String, _ article: String,
        buy: Decimal, sell: Decimal, unit: ProductUnit = .stueck, tier: OfferTier = .standard,
        specs: ProductSpecs = ProductSpecs()
    ) -> ProductRecord {
        ProductRecord(
            manufacturer: m, category: category, role: role, name: name, articleNumber: article, unit: unit,
            purchasePrice: buy, sellPrice: sell, tier: tier, specs: specs
        )
    }

    // MARK: - Eufy

    static var eufy: [ProductRecord] {
        [
            camera(.eufy, "eufy SoloCam S220 (2K, Akku/Solar)", "T8134", buy: chf(89), sell: chf(129), tier: .budget,
                   mp: 3, audio: .gegensprechen, form: .bullet, poe: false, wifi: true, battery: true),
            camera(.eufy, "eufyCam S3 Pro (4K, Akku/Solar, Farbnachtsicht)", "T8162", buy: chf(229), sell: chf(299), tier: .premium,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .bullet, poe: false, wifi: true, battery: true),
            camera(.eufy, "eufy SoloCam S340 (3K, Solar, schwenkbar)", "T8170", buy: chf(139), sell: chf(189), tier: .standard,
                   mp: 5, night: .farbeNacht, audio: .gegensprechen, form: .bullet, poe: false, wifi: true, battery: true, ptz: true),
            camera(.eufy, "eufy Floodlight Cam E340 (Netzbetrieb, WLAN)", "T8425", buy: chf(159), sell: chf(219), tier: .standard,
                   mp: 6, night: .farbeNacht, audio: .gegensprechen, form: .bullet, poe: false, wifi: true),
            camera(.eufy, "eufy Indoor Cam E30 (4K, schwenkbar, WLAN)", "T8417", buy: chf(49), sell: chf(79), tier: .budget,
                   mp: 8, outdoor: false, audio: .gegensprechen, form: .dome, poe: false, wifi: true, ptz: true),
            recorder(.eufy, "eufy HomeBase S380 (Zentrale, lokaler Speicher)", "T8030", buy: chf(129), sell: chf(179), tier: .standard,
                     channels: 16, poePorts: 0, bays: 1, wifi: true)
        ]
    }

    // MARK: - Reolink

    static var reolink: [ProductRecord] {
        [
            camera(.reolink, "Reolink RLC-510A (5 MP Bullet, PoE)", "RLC-510A", buy: chf(49), sell: chf(79), tier: .budget,
                   mp: 5, audio: .mithoeren, form: .bullet),
            camera(.reolink, "Reolink RLC-820A (8 MP Bullet, PoE)", "RLC-820A", buy: chf(69), sell: chf(109), tier: .standard,
                   mp: 8, audio: .mithoeren, form: .bullet),
            camera(.reolink, "Reolink RLC-833A (8 MP Turret, Spotlight, Farbnachtsicht)", "RLC-833A", buy: chf(89), sell: chf(139), tier: .standard,
                   mp: 8, night: .farbeNacht, audio: .mithoeren, form: .turret),
            camera(.reolink, "Reolink RLC-840A (8 MP Turret, Zwei-Wege-Audio)", "RLC-840A", buy: chf(99), sell: chf(149), tier: .premium,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .turret),
            camera(.reolink, "Reolink Duo 3 PoE (16 MP Panorama)", "DUO3-POE", buy: chf(159), sell: chf(229), tier: .premium,
                   mp: 16, night: .farbeNacht, audio: .gegensprechen, form: .bullet),
            camera(.reolink, "Reolink RLC-823A (8 MP PTZ, 5x Zoom, PoE)", "RLC-823A", buy: chf(209), sell: chf(299), tier: .premium,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .ptz, ptz: true),
            camera(.reolink, "Reolink RLC-520A (5 MP Dome, PoE)", "RLC-520A", buy: chf(55), sell: chf(89), tier: .budget,
                   mp: 5, audio: .mithoeren, form: .dome),
            camera(.reolink, "Reolink E1 Zoom (5 MP, schwenkbar, WLAN, innen)", "E1-ZOOM", buy: chf(69), sell: chf(99), tier: .standard,
                   mp: 5, outdoor: false, audio: .gegensprechen, form: .dome, poe: false, wifi: true, ptz: true),
            camera(.reolink, "Reolink Argus 4 Pro (4K, Akku/Solar, Farbnachtsicht)", "ARGUS4PRO", buy: chf(139), sell: chf(199), tier: .standard,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .bullet, poe: false, wifi: true, battery: true),
            camera(.reolink, "Reolink RLC-811WA (8 MP, WLAN, 5x Zoom)", "RLC-811WA", buy: chf(119), sell: chf(169), tier: .standard,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .bullet, poe: false, wifi: true),
            recorder(.reolink, "Reolink RLN8-410 (NVR 8 Kanäle, 8 PoE, 1 HDD)", "RLN8-410", buy: chf(179), sell: chf(259), tier: .budget,
                     channels: 8, poePorts: 8, bays: 1),
            recorder(.reolink, "Reolink RLN16-410 (NVR 16 Kanäle, 16 PoE, 4 HDD)", "RLN16-410", buy: chf(299), sell: chf(429), tier: .standard,
                     channels: 16, poePorts: 16, bays: 4),
            recorder(.reolink, "Reolink RLN36 (NVR 36 Kanäle, 8 HDD)", "RLN36", buy: chf(549), sell: chf(799), tier: .premium,
                     channels: 36, poePorts: 0, bays: 8)
        ]
    }

    // MARK: - Dahua

    static var dahua: [ProductRecord] {
        [
            camera(.dahua, "Dahua IPC-HFW2441S-S (4 MP Bullet, WizSense)", "IPC-HFW2441S-S-0280B", buy: chf(99), sell: chf(149), tier: .budget,
                   mp: 4, audio: .mithoeren, form: .bullet),
            camera(.dahua, "Dahua IPC-HDW2849H-S-IL (8 MP Turret, Smart Dual Light)", "IPC-HDW2849H-S-IL-0280B", buy: chf(139), sell: chf(199), tier: .standard,
                   mp: 8, night: .farbeNacht, audio: .mithoeren, form: .turret),
            camera(.dahua, "Dahua IPC-HFW3849T1-AS-PV (8 MP TiOC, aktive Abschreckung)", "IPC-HFW3849T1-AS-PV-0280B", buy: chf(219), sell: chf(309), tier: .premium,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .bullet),
            camera(.dahua, "Dahua IPC-HDBW3441R-ZS (4 MP Dome, Varifokal)", "IPC-HDBW3441R-ZS-27135", buy: chf(189), sell: chf(269), tier: .standard,
                   mp: 4, audio: .mithoeren, form: .dome),
            camera(.dahua, "Dahua IPC-HDBW3841E-AS (8 MP Dome, WizSense)", "IPC-HDBW3841E-AS-0280B", buy: chf(169), sell: chf(239), tier: .premium,
                   mp: 8, audio: .mithoeren, form: .dome),
            camera(.dahua, "Dahua SD49425XB-HNR (4 MP PTZ, 25x Zoom)", "SD49425XB-HNR", buy: chf(899), sell: chf(1249), tier: .premium,
                   mp: 4, audio: .mithoeren, form: .ptz, ptz: true),
            camera(.dahua, "Dahua ITC413-PW4D-IZ1 (4 MP Kennzeichenkamera)", "ITC413-PW4D-IZ1", buy: chf(749), sell: chf(1049), tier: .premium,
                   mp: 4, form: .bullet, lpr: true),
            recorder(.dahua, "Dahua NVR4108HS-8P-4KS3 (8 Kanäle, 8 PoE, 1 HDD)", "NVR4108HS-8P-4KS3", buy: chf(199), sell: chf(289), tier: .budget,
                     channels: 8, poePorts: 8, bays: 1),
            recorder(.dahua, "Dahua NVR4216-16P-4KS3 (16 Kanäle, 16 PoE, 2 HDD)", "NVR4216-16P-4KS3", buy: chf(389), sell: chf(549), tier: .standard,
                     channels: 16, poePorts: 16, bays: 2),
            recorder(.dahua, "Dahua NVR5432-16P-EI (32 Kanäle, 16 PoE, 4 HDD, WizSense)", "NVR5432-16P-EI", buy: chf(899), sell: chf(1249), tier: .premium,
                     channels: 32, poePorts: 16, bays: 4),
            item(.dahua, .poeSwitch, .poeSwitch, "Dahua PFS3010-8ET-96 (8 Port PoE-Switch, 96 W)", "PFS3010-8ET-96",
                 buy: chf(89), sell: chf(129), specs: ProductSpecs(supportsPoE: true, channels: 8, poePorts: 8)),
            item(.dahua, .poeSwitch, .poeSwitch, "Dahua PFS3218-16ET-135 (16 Port PoE-Switch, 135 W)", "PFS3218-16ET-135",
                 buy: chf(169), sell: chf(239), specs: ProductSpecs(supportsPoE: true, channels: 16, poePorts: 16))
        ]
    }

    // MARK: - Uniview

    static var uniview: [ProductRecord] {
        [
            camera(.uniview, "Uniview IPC2124LB-SF28KM-G (4 MP Bullet)", "IPC2124LB-SF28KM-G", buy: chf(79), sell: chf(119), tier: .budget,
                   mp: 4, audio: .mithoeren, form: .bullet, ai: false),
            camera(.uniview, "Uniview IPC3618SB-ADF28KM-I0 (8 MP Turret, LightHunter)", "IPC3618SB-ADF28KM-I0", buy: chf(129), sell: chf(185), tier: .standard,
                   mp: 8, audio: .mithoeren, form: .turret),
            camera(.uniview, "Uniview IPC2128SB-ADF28KM-I0 (8 MP Bullet, ColorHunter)", "IPC2128SB-ADF28KM-I0", buy: chf(159), sell: chf(229), tier: .premium,
                   mp: 8, night: .farbeNacht, audio: .gegensprechen, form: .bullet),
            camera(.uniview, "Uniview IPC3238SB-ADZK-I0 (8 MP Dome, Varifokal)", "IPC3238SB-ADZK-I0", buy: chf(219), sell: chf(309), tier: .premium,
                   mp: 8, audio: .mithoeren, form: .dome),
            camera(.uniview, "Uniview IPC322LB-SF28-A (2 MP Dome, innen/aussen)", "IPC322LB-SF28-A", buy: chf(59), sell: chf(89), tier: .budget,
                   mp: 2, form: .dome, ai: false),
            camera(.uniview, "Uniview IPC6424SR-X25-VF (4 MP PTZ, 25x Zoom)", "IPC6424SR-X25-VF", buy: chf(749), sell: chf(1049), tier: .premium,
                   mp: 4, form: .ptz, ptz: true),
            camera(.uniview, "Uniview IPC2124SR5-ADZK-LPR (4 MP Kennzeichenkamera)", "IPC2124SR5-LPR", buy: chf(549), sell: chf(769), tier: .premium,
                   mp: 4, form: .bullet, lpr: true),
            recorder(.uniview, "Uniview NVR301-08S3-P8 (8 Kanäle, 8 PoE, 1 HDD)", "NVR301-08S3-P8", buy: chf(159), sell: chf(229), tier: .budget,
                     channels: 8, poePorts: 8, bays: 1),
            recorder(.uniview, "Uniview NVR302-16S2-P16 (16 Kanäle, 16 PoE, 2 HDD)", "NVR302-16S2-P16", buy: chf(299), sell: chf(429), tier: .standard,
                     channels: 16, poePorts: 16, bays: 2),
            recorder(.uniview, "Uniview NVR304-32S-P16 (32 Kanäle, 16 PoE, 4 HDD)", "NVR304-32S-P16", buy: chf(649), sell: chf(899), tier: .premium,
                     channels: 32, poePorts: 16, bays: 4)
        ]
    }

    // MARK: - Axis

    static var axis: [ProductRecord] {
        [
            camera(.axis, "AXIS M2036-LE Mk II (4 MP Bullet, kompakt)", "02999-001", buy: chf(299), sell: chf(419), tier: .budget,
                   mp: 4, form: .bullet),
            camera(.axis, "AXIS M3088-V (8 MP Mini-Dome, innen)", "02373-001", buy: chf(279), sell: chf(389), tier: .budget,
                   mp: 8, outdoor: false, night: .keine, form: .dome),
            camera(.axis, "AXIS P3268-LV (8 MP Dome, Lightfinder 2.0)", "02331-001", buy: chf(899), sell: chf(1199), tier: .standard,
                   mp: 8, outdoor: false, form: .dome),
            camera(.axis, "AXIS P3268-LVE (8 MP Dome aussen, Lightfinder 2.0)", "02332-001", buy: chf(999), sell: chf(1329), tier: .standard,
                   mp: 8, night: .farbeNacht, audio: .mithoeren, form: .dome),
            camera(.axis, "AXIS P1468-XLE (8 MP Bullet, Forensic WDR)", "02447-001", buy: chf(949), sell: chf(1269), tier: .standard,
                   mp: 8, night: .farbeNacht, form: .bullet),
            camera(.axis, "AXIS Q1808-LE (32 MP Bullet, Premium)", "02436-001", buy: chf(2490), sell: chf(3290), tier: .premium,
                   mp: 32, night: .farbeNacht, audio: .mithoeren, form: .bullet),
            camera(.axis, "AXIS Q6318-LE (4K PTZ, 31x Zoom)", "02153-002", buy: chf(4990), sell: chf(6490), tier: .premium,
                   mp: 8, night: .infrarot, form: .ptz, ptz: true),
            camera(.axis, "AXIS P1465-LE-3 License Plate Verifier Kit", "02209-001", buy: chf(1290), sell: chf(1690), tier: .premium,
                   mp: 2, form: .bullet, lpr: true),
            camera(.axis, "AXIS I8016-LVE (Netzwerk-Videotürsprechstelle)", "02368-001", buy: chf(549), sell: chf(749), tier: .premium,
                   mp: 5, audio: .gegensprechen, form: .turret),
            recorder(.axis, "AXIS S3008 Mk II Recorder (8 Kanäle, 8 PoE)", "02802-002", buy: chf(1190), sell: chf(1590), tier: .standard,
                     channels: 8, poePorts: 8, bays: 1),
            recorder(.axis, "AXIS S3016 Recorder (16 Kanäle, 3 HDD)", "02108-002", buy: chf(2290), sell: chf(2990), tier: .premium,
                     channels: 16, poePorts: 0, bays: 3),
            item(.axis, .lizenz, .vmsLizenz, "AXIS Camera Station Pro – Core-Lizenz pro Kanal", "02848-001",
                 buy: chf(129), sell: chf(169), unit: .lizenz, tier: .premium),
            item(.axis, .poeSwitch, .poeSwitch, "AXIS T8516 PoE+ Network Switch (16 Port)", "01992-002",
                 buy: chf(1190), sell: chf(1590), tier: .premium, specs: ProductSpecs(supportsPoE: true, channels: 16, poePorts: 16))
        ]
    }

    // MARK: - Herstellerneutral

    static var neutral: [ProductRecord] {
        [
            item(.neutral, .festplatte, .festplatte, "Überwachungsfestplatte 4 TB (z. B. WD Purple)", "HDD-SURV-4TB", buy: chf(99), sell: chf(139),
                 specs: ProductSpecs(capacityTB: 4)),
            item(.neutral, .festplatte, .festplatte, "Überwachungsfestplatte 8 TB (z. B. WD Purple)", "HDD-SURV-8TB", buy: chf(179), sell: chf(249),
                 specs: ProductSpecs(capacityTB: 8)),
            item(.neutral, .festplatte, .festplatte, "Überwachungsfestplatte 12 TB (z. B. Seagate SkyHawk)", "HDD-SURV-12TB", buy: chf(269), sell: chf(369),
                 specs: ProductSpecs(capacityTB: 12)),
            item(.neutral, .festplatte, .festplatte, "Überwachungsfestplatte 16 TB (z. B. Seagate SkyHawk AI)", "HDD-SURV-16TB", buy: chf(349), sell: chf(469),
                 specs: ProductSpecs(capacityTB: 16)),
            item(.neutral, .zubehoer, .speicherkarte, "microSD-Karte 128 GB (High Endurance)", "SD-128-HE", buy: chf(19), sell: chf(29)),
            item(.neutral, .poeSwitch, .poeSwitch, "PoE+-Switch 8 Port Gigabit (120 W, managed)", "SW-POE-8", buy: chf(89), sell: chf(139),
                 specs: ProductSpecs(supportsPoE: true, channels: 8, poePorts: 8)),
            item(.neutral, .poeSwitch, .poeSwitch, "PoE+-Switch 16 Port Gigabit (250 W, managed)", "SW-POE-16", buy: chf(229), sell: chf(319),
                 specs: ProductSpecs(supportsPoE: true, channels: 16, poePorts: 16)),
            item(.neutral, .poeSwitch, .poeSwitch, "PoE+-Switch 24 Port Gigabit (370 W, managed)", "SW-POE-24", buy: chf(389), sell: chf(529),
                 specs: ProductSpecs(supportsPoE: true, channels: 24, poePorts: 24)),
            item(.neutral, .usv, .usv, "USV 650 VA (Line-Interactive)", "USV-650", buy: chf(99), sell: chf(149),
                 specs: ProductSpecs(powerVA: 650)),
            item(.neutral, .usv, .usv, "USV 1500 VA (Line-Interactive, Rack/Tower)", "USV-1500", buy: chf(349), sell: chf(479),
                 specs: ProductSpecs(powerVA: 1500)),
            item(.neutral, .netzwerkkabel, .kabel, "Netzwerkkabel Cat. 6A S/FTP, halogenfrei", "CAB-CAT6A", buy: chf(1, 10), sell: chf(2, 80), unit: .meter),
            item(.neutral, .zubehoer, .stecker, "RJ45-Stecker und Anschlussmaterial (pro Kamera)", "RJ45-SET", buy: chf(6), sell: chf(14)),
            item(.neutral, .montagematerial, .halterung, "Wand- oder Masthalter (pro Kamera)", "MNT-WALL", buy: chf(19), sell: chf(35)),
            item(.neutral, .montagematerial, .anschlussdose, "Anschlussdose wetterfest IP66 (Junction Box)", "MNT-JBOX", buy: chf(14), sell: chf(29)),
            item(.neutral, .montagematerial, .kabelkanal, "Kabelkanal, Rohr und Befestigung (pro Kamera)", "MNT-DUCT", buy: chf(12), sell: chf(25)),
            item(.neutral, .beschilderung, .schildKlein, "Hinweisschild «Videoüberwachung» A5, wetterfest", "SIGN-A5", buy: chf(9), sell: chf(24)),
            item(.neutral, .beschilderung, .schildGross, "Hinweisschild «Videoüberwachung» A4 mit Angabe Betreiber", "SIGN-A4", buy: chf(14), sell: chf(34)),
            item(.neutral, .zubehoer, .hebebuehne, "Hebebühne (Miete inkl. Transport, pro Tag)", "LIFT-DAY", buy: chf(220), sell: chf(320), unit: .tag),
            item(.neutral, .zubehoer, .monitor, "Monitor 24\" für Live-Anzeige vor Ort", "MON-24", buy: chf(149), sell: chf(219)),
            item(.neutral, .zubehoer, .rack, "Netzwerkschrank 9 HE (Wandmontage)", "RACK-9HE", buy: chf(189), sell: chf(279))
        ]
    }
}
