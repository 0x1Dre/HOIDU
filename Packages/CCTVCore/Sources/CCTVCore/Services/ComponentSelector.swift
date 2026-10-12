import Foundation

public struct ComponentSelection: Codable, Hashable, Sendable {
    public var manufacturer: Manufacturer
    public var tier: OfferTier
    public var materialItems: [OfferLineItem]
    public var cameraCount: Int
    public var recorderCount: Int
    public var switchCount: Int
    public var hasUPS: Bool
    public var hasRack: Bool
    public var cableMeters: Int
    public var averageMegapixels: Double
    public var storage: StorageResult?
    public var notes: [String]
    public var warnings: [String]

    public var isAvailable: Bool { cameraCount > 0 }
}

/// Wählt Komponenten aus den Preislisten passend zu Projekt, Hersteller und Variante.
public enum ComponentSelector {
    struct CameraNeed {
        var outdoor: Bool
        var minMegapixels: Int
        var nightVision: NightVision
        var audio: AudioMode
        var ptz: Bool
        var lpr: Bool
        var connection: ConnectionType
        var formFactor: CameraFormFactor
    }

    public static func select(
        project: ProjectRecord,
        manufacturer: Manufacturer,
        tier: OfferTier,
        catalog: ProductCatalog,
        settings: CalculationSettings
    ) -> ComponentSelection {
        let profile = ProjectProfile(project: project)
        let infra = project.infrastructure
        var notes: [String] = []
        var warnings: [String] = []
        var items: [OfferLineItem] = []

        // MARK: Kameras
        let cameraCandidates = catalog.products(of: manufacturer, role: .kamera)
        var cameraLines: [UUID: (product: ProductRecord, quantity: Int, areas: [String])] = [:]
        var cameraOrder: [UUID] = []
        var cameraCount = 0
        var megapixelSum = 0

        for area in project.areas where area.camera.quantity > 0 {
            let need = cameraNeed(for: area, project: project, tier: tier)
            guard let choice = chooseCamera(need: need, tier: tier, candidates: cameraCandidates) else {
                warnings.append("Bereich «\(area.name)»: Keine Kamera von \(manufacturer.label) in der Preisliste.")
                continue
            }
            for compromise in choice.compromises {
                warnings.append("Bereich «\(area.name)»: \(compromise)")
            }
            let qty = area.camera.quantity
            cameraCount += qty
            megapixelSum += choice.product.specs.megapixels * qty
            if var line = cameraLines[choice.product.id] {
                line.quantity += qty
                line.areas.append(area.name)
                cameraLines[choice.product.id] = line
            } else {
                cameraLines[choice.product.id] = (choice.product, qty, [area.name])
                cameraOrder.append(choice.product.id)
            }
        }

        for id in cameraOrder {
            guard let line = cameraLines[id] else { continue }
            let areaText = line.areas.filter { !$0.isEmpty }.joined(separator: ", ")
            let description = areaText.isEmpty ? line.product.name : "\(line.product.name) – \(areaText)"
            items.append(OfferLineItem(product: line.product, quantity: Decimal(line.quantity), description: description))
        }

        guard cameraCount > 0 else {
            return ComponentSelection(
                manufacturer: manufacturer, tier: tier, materialItems: [], cameraCount: 0, recorderCount: 0,
                switchCount: 0, hasUPS: false, hasRack: false, cableMeters: 0, averageMegapixels: 0,
                storage: nil, notes: notes,
                warnings: warnings.isEmpty ? ["Für \(manufacturer.label) konnte keine Variante berechnet werden."] : warnings
            )
        }

        let averageMP = Double(megapixelSum) / Double(cameraCount)

        // MARK: Rekorder
        var recorderCount = 0
        var recorderBays = 0
        var recorderPoEPorts = 0
        let batteryOnly = profile.usesBattery && manufacturer != .eufy

        if infra.existing.contains(.nvr) {
            notes.append("Bestehender NVR wird weiterverwendet – Kanäle, Speicher und Kompatibilität prüfen.")
        } else if batteryOnly {
            if let card = cheapest(catalog.productsPreferring(manufacturer, role: .speicherkarte)) {
                items.append(OfferLineItem(product: card, quantity: Decimal(cameraCount)))
            }
            notes.append("Akkukameras speichern lokal auf Speicherkarte; kein Rekorder vorgesehen.")
        } else {
            let recorders = catalog.productsPreferring(manufacturer, role: .rekorder)
            if let pick = chooseRecorder(recorders, cameras: cameraCount, tier: tier) {
                recorderCount = pick.count
                recorderBays = pick.product.specs.driveBays * pick.count
                recorderPoEPorts = pick.product.specs.poePorts * pick.count
                items.append(OfferLineItem(product: pick.product, quantity: Decimal(pick.count)))
                if pick.count > 1 {
                    notes.append("\(pick.count) Rekorder nötig, da ein Gerät maximal \(pick.product.specs.channels) Kanäle unterstützt.")
                }
            } else {
                warnings.append("Kein passender Rekorder in der Preisliste von \(manufacturer.label).")
            }
            if manufacturer == .axis && (profile.needsVMS || tier == .premium),
               let license = cheapest(catalog.products(of: .axis, role: .vmsLizenz)) {
                items.append(OfferLineItem(product: license, quantity: Decimal(cameraCount)))
            }
        }

        // MARK: Speicher
        let diskCandidates = catalog.productsPreferring(manufacturer, role: .festplatte)
            .filter { $0.specs.capacityTB > 0 }
            .sorted { $0.specs.capacityTB < $1.specs.capacityTB }
        var storage: StorageResult?

        func storageInput(diskTB: Int, redundancy: Bool) -> StorageInput {
            StorageInput(
                cameras: cameraCount,
                megapixels: max(1, averageMP),
                framesPerSecond: min(max(project.recording.framesPerSecond, 1), 60),
                codec: project.recording.codec,
                mode: profile.usesBattery ? .ereignis : project.recording.mode,
                eventSharePercent: Double(settings.eventRecordingSharePercent),
                scheduleHoursPerDay: Double(project.recording.scheduleHoursPerDay),
                retentionDays: min(max(project.recording.retentionDays, 1), 365),
                safetyMarginPercent: Double(settings.storageSafetyMarginPercent),
                diskSizeTB: max(1, diskTB),
                redundancyDisk: redundancy
            )
        }

        if recorderCount > 0 && recorderBays > 0 && !diskCandidates.isEmpty {
            let wantsRedundancy = tier == .premium && recorderBays >= 3
            var chosen: (ProductRecord, StorageResult)?
            for disk in diskCandidates where disk.specs.capacityTB >= min(settings.defaultDiskSizeTB, diskCandidates.last!.specs.capacityTB) {
                if let result = try? StorageCalculator.calculate(storageInput(diskTB: disk.specs.capacityTB, redundancy: wantsRedundancy)),
                   result.recommendedDisks <= recorderBays {
                    chosen = (disk, result)
                    break
                }
            }
            if chosen == nil, let largest = diskCandidates.last,
               let result = try? StorageCalculator.calculate(storageInput(diskTB: largest.specs.capacityTB, redundancy: false)) {
                chosen = (largest, result)
                if result.recommendedDisks > recorderBays {
                    warnings.append("Speicherbedarf von \(Format.number(result.requiredTBWithMargin, fractionDigits: 1)) TB übersteigt die Rekorderkapazität (\(recorderBays) Schächte). Aufbewahrung reduzieren oder grösseren Rekorder wählen.")
                }
            }
            if let (disk, result) = chosen {
                storage = result
                let count = min(result.recommendedDisks, recorderBays)
                items.append(OfferLineItem(product: disk, quantity: Decimal(count)))
                if result.recommendedDisks > 1 && result.assumptions.contains(where: { $0.contains("Redundanz") }) {
                    notes.append("Eine zusätzliche Festplatte für Redundanz eingerechnet.")
                }
            }
        } else {
            storage = try? StorageCalculator.calculate(storageInput(diskTB: settings.defaultDiskSizeTB, redundancy: false))
            if infra.existing.contains(.nvr), let storage {
                notes.append("Benötigter Speicher am bestehenden NVR: \(Format.number(storage.requiredTBWithMargin, fractionDigits: 1)) TB.")
            }
        }

        // MARK: Netzwerk
        var switchCount = 0
        if profile.usesPoE {
            if infra.existing.contains(.poeSwitch) {
                notes.append("Bestehender Switch: PoE-Budget und freie Ports prüfen.")
            } else if cameraCount > recorderPoEPorts {
                let neededPorts = cameraCount - recorderPoEPorts + (recorderCount > 0 ? 1 : 0)
                let switches = catalog.productsPreferring(manufacturer, role: .poeSwitch)
                    .sorted { $0.specs.channels < $1.specs.channels }
                if let fitting = switches.first(where: { $0.specs.channels >= neededPorts }) {
                    switchCount = 1
                    items.append(OfferLineItem(product: fitting, quantity: 1))
                } else if let largest = switches.last, largest.specs.channels > 1 {
                    switchCount = Int((Double(neededPorts) / Double(largest.specs.channels - 1)).rounded(.up))
                    items.append(OfferLineItem(product: largest, quantity: Decimal(switchCount)))
                } else {
                    warnings.append("Kein PoE-Switch in den Preislisten gefunden.")
                }
            }
        }

        let hasCentralHardware = recorderCount > 0 || switchCount > 0
        var hasUPS = false
        if hasCentralHardware && !infra.existing.contains(.usv) && (tier != .budget || profile.continuousRecording) {
            let upsList = catalog.productsPreferring(manufacturer, role: .usv).sorted { $0.specs.powerVA < $1.specs.powerVA }
            if let ups = cameraCount <= 8 ? upsList.first : upsList.last {
                hasUPS = true
                items.append(OfferLineItem(product: ups, quantity: 1))
            }
        }

        var hasRack = false
        if hasCentralHardware && !infra.existing.contains(.rack) && cameraCount > 8 && tier != .budget,
           let rack = cheapest(catalog.productsPreferring(manufacturer, role: .rack)) {
            hasRack = true
            items.append(OfferLineItem(product: rack, quantity: 1))
        }

        // MARK: Verkabelung und Montage
        var cableMeters = 0
        if profile.usesPoE {
            let raw = Decimal(cameraCount * settings.cableMetersPerCamera) * infra.cabling.newCableShare
            let meters = Int(raw.asDouble.rounded(.up))
            cableMeters = meters == 0 ? 0 : ((meters + 4) / 5) * 5
            if cableMeters > 0, let cable = cheapest(catalog.productsPreferring(manufacturer, role: .kabel)) {
                items.append(OfferLineItem(product: cable, quantity: Decimal(cableMeters)))
            }
            if let connector = cheapest(catalog.productsPreferring(manufacturer, role: .stecker)) {
                items.append(OfferLineItem(product: connector, quantity: Decimal(cameraCount)))
            }
            if infra.cabling == .unklar {
                notes.append("Kabellänge geschätzt (\(settings.cableMetersPerCamera) m pro Kamera, 75 % neu).")
            }
        }

        let outdoorCameras = project.areas
            .filter { $0.location == .aussen }
            .reduce(0) { $0 + max(0, $1.camera.quantity) }
        if outdoorCameras > 0, let bracket = cheapest(catalog.productsPreferring(manufacturer, role: .halterung)) {
            items.append(OfferLineItem(product: bracket, quantity: Decimal(min(outdoorCameras, cameraCount))))
        }
        if outdoorCameras > 0 && profile.usesPoE && tier != .budget,
           let box = cheapest(catalog.productsPreferring(manufacturer, role: .anschlussdose)) {
            items.append(OfferLineItem(product: box, quantity: Decimal(min(outdoorCameras, cameraCount))))
        }
        if cableMeters > 0, let duct = cheapest(catalog.productsPreferring(manufacturer, role: .kabelkanal)) {
            items.append(OfferLineItem(product: duct, quantity: Decimal(cameraCount)))
        }

        // MARK: Zubehör
        let outdoorAreas = project.areas.filter { $0.location == .aussen && $0.camera.quantity > 0 }.count
        let signCount = min(6, max(1, outdoorAreas))
        let signRole: ComponentRole = tier == .budget ? .schildKlein : .schildGross
        if let sign = cheapest(catalog.productsPreferring(manufacturer, role: signRole))
            ?? cheapest(catalog.productsPreferring(manufacturer, role: .schildKlein)) {
            items.append(OfferLineItem(product: sign, quantity: Decimal(signCount)))
        }
        if infra.mountingAccess == .hebebuehne,
           let lift = cheapest(catalog.productsPreferring(manufacturer, role: .hebebuehne)) {
            let days = max(1, Int((Double(cameraCount) / 8).rounded(.up)))
            items.append(OfferLineItem(product: lift, quantity: Decimal(days)))
        }
        if project.recording.access.contains(.monitorVorOrt),
           let monitor = cheapest(catalog.productsPreferring(manufacturer, role: .monitor)) {
            items.append(OfferLineItem(product: monitor, quantity: 1))
        }

        return ComponentSelection(
            manufacturer: manufacturer,
            tier: tier,
            materialItems: items,
            cameraCount: cameraCount,
            recorderCount: recorderCount,
            switchCount: switchCount,
            hasUPS: hasUPS,
            hasRack: hasRack,
            cableMeters: cableMeters,
            averageMegapixels: averageMP,
            storage: storage,
            notes: notes,
            warnings: warnings
        )
    }

    // MARK: - Hilfsfunktionen

    static func cameraNeed(for area: SiteAreaRecord, project: ProjectRecord, tier: OfferTier) -> CameraNeed {
        let features = project.recording.features
        var minMP = area.requiredMegapixels
        switch tier {
        case .budget: break
        case .standard: minMP = max(minMP, 4)
        case .premium: minMP = max(minMP, 8)
        }
        var audio = area.audio
        if audio == .nein && features.contains(.zweiWegeAudio) { audio = .gegensprechen }
        return CameraNeed(
            outdoor: area.location == .aussen,
            minMegapixels: minMP,
            nightVision: area.nightVision,
            audio: audio,
            ptz: area.camera.formFactor == .ptz,
            lpr: area.detectionTarget == .kennzeichen,
            connection: project.infrastructure.connection,
            formFactor: area.camera.formFactor
        )
    }

    static func connectionMatches(_ product: ProductRecord, _ connection: ConnectionType) -> Bool {
        switch connection {
        case .poeLan: product.specs.supportsPoE
        case .wlan: product.specs.supportsWiFi
        case .akku, .solar: product.specs.isBattery
        }
    }

    static func chooseCamera(
        need: CameraNeed,
        tier: OfferTier,
        candidates: [ProductRecord]
    ) -> (product: ProductRecord, compromises: [String])? {
        guard !candidates.isEmpty else { return nil }
        var compromises: [String] = []

        var pool = candidates.filter { connectionMatches($0, need.connection) && (!need.outdoor || $0.specs.isOutdoor) }
        if pool.isEmpty {
            pool = candidates.filter { !need.outdoor || $0.specs.isOutdoor }
            if !pool.isEmpty {
                compromises.append("Keine Kamera mit Anschluss \(need.connection.label) verfügbar – abweichende Anschlussart gewählt.")
            }
        }
        if pool.isEmpty {
            pool = candidates
            compromises.append("Keine Aussenkamera verfügbar – Innenkamera nur mit Wetterschutzgehäuse einsetzbar.")
        }

        func penalty(_ product: ProductRecord) -> Int {
            let s = product.specs
            var value = 0
            if s.megapixels < need.minMegapixels { value += 2 }
            if need.ptz != s.isPTZ { value += need.ptz ? 3 : 2 }
            if need.lpr != s.hasLPR { value += 3 }
            if need.nightVision != .keine && s.nightVision == .keine { value += 2 }
            if need.nightVision == .farbeNacht && s.nightVision != .farbeNacht { value += 1 }
            if need.audio == .gegensprechen && s.audio != .gegensprechen { value += 1 }
            if need.audio == .mithoeren && s.audio == .nein { value += 1 }
            if need.formFactor != .automatisch && need.formFactor != .ptz && s.formFactor != need.formFactor { value += 1 }
            return value
        }

        let ranked = pool.sorted { a, b in
            let pa = penalty(a), pb = penalty(b)
            if pa != pb { return pa < pb }
            let da = abs(a.tier.rank - tier.rank), db = abs(b.tier.rank - tier.rank)
            if da != db { return da < db }
            return tier == .premium ? a.sellPrice > b.sellPrice : a.sellPrice < b.sellPrice
        }
        guard let best = ranked.first else { return nil }

        let s = best.specs
        if s.megapixels < need.minMegapixels {
            compromises.append("Auflösung \(s.megapixels) MP liegt unter dem Richtwert von \(need.minMegapixels) MP.")
        }
        if need.ptz && !s.isPTZ { compromises.append("Keine PTZ-Kamera verfügbar.") }
        if need.lpr && !s.hasLPR { compromises.append("Keine spezialisierte Kennzeichenkamera verfügbar.") }
        if need.nightVision != .keine && s.nightVision == .keine { compromises.append("Gewählte Kamera ohne Nachtsicht.") }
        if need.nightVision == .farbeNacht && s.nightVision == .infrarot { compromises.append("Nur IR-Nachtsicht statt Farbbild bei Nacht.") }
        if need.audio == .gegensprechen && s.audio != .gegensprechen { compromises.append("Kein Gegensprechen möglich.") }
        return (best, compromises)
    }

    static func chooseRecorder(
        _ recorders: [ProductRecord],
        cameras: Int,
        tier: OfferTier
    ) -> (product: ProductRecord, count: Int)? {
        let valid = recorders.filter { $0.specs.channels > 0 }
        guard !valid.isEmpty else { return nil }
        let fitting = valid.filter { $0.specs.channels >= cameras }
        if !fitting.isEmpty {
            let sorted = fitting.sorted {
                if $0.specs.channels != $1.specs.channels { return $0.specs.channels < $1.specs.channels }
                let da = abs($0.tier.rank - tier.rank), db = abs($1.tier.rank - tier.rank)
                if da != db { return da < db }
                return $0.sellPrice < $1.sellPrice
            }
            return (sorted[0], 1)
        }
        let largest = valid.max { $0.specs.channels < $1.specs.channels }!
        let count = Int((Double(cameras) / Double(largest.specs.channels)).rounded(.up))
        return (largest, count)
    }

    static func cheapest(_ products: [ProductRecord]) -> ProductRecord? {
        products.min { $0.sellPrice < $1.sellPrice }
    }
}
