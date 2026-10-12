import Foundation
import SwiftData

/// Gleicht eine To-many-Beziehung mit einer Liste von Domänenobjekten ab:
/// vorhandene Objekte werden aktualisiert, neue eingefügt und fehlende gelöscht.
/// So bleiben unveränderte Fotos auf der Festplatte und werden nicht neu geschrieben.
/// Bewusst nicht an einen Actor gebunden: läuft synchron auf dem Kontext (und Actor) des Aufrufers.
enum ModelSync {
    nonisolated static func sync<Model: PersistentModel, Record: Identifiable>(
        _ existing: [Model],
        with records: [Record],
        context: ModelContext,
        id: (Model) -> UUID,
        create: (Record) -> Model,
        update: (Model, Record, Int) -> Void
    ) -> [Model] where Record.ID == UUID {
        var remaining: [UUID: Model] = [:]
        for model in existing {
            remaining[id(model)] = model
        }
        var result: [Model] = []
        for (index, record) in records.enumerated() {
            let model: Model
            if let found = remaining.removeValue(forKey: record.id) {
                model = found
            } else {
                model = create(record)
                context.insert(model)
            }
            update(model, record, index)
            result.append(model)
        }
        for leftover in remaining.values {
            context.delete(leftover)
        }
        return result
    }
}
