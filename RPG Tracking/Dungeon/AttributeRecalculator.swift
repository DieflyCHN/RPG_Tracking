//
//  AttributeRecalculator.swift
//  RPG Tracking
//
//  Keeps attribute experience consistent when logs are edited/deleted.
//

import Foundation
import SwiftData

enum AttributeRecalculator {
    static func recalculateAttributes(_ attributes: [RPGAttribute], in context: ModelContext) {
        guard !attributes.isEmpty else { return }

        let ids = Set(attributes.map(\.id))
        let descriptor = FetchDescriptor<DungeonEffectLog>()
        let allEffects = (try? context.fetch(descriptor)) ?? []

        var totals: [UUID: Double] = [:]
        var latest: [UUID: Date] = [:]

        for effect in allEffects {
            guard let attrID = effect.attribute?.id, ids.contains(attrID) else { continue }
            totals[attrID, default: 0] += effect.earned

            if effect.earned > 0, let date = effect.log?.date {
                if let existing = latest[attrID] {
                    if date > existing { latest[attrID] = date }
                } else {
                    latest[attrID] = date
                }
            }
        }

        for attr in attributes {
            attr.experience = totals[attr.id, default: 0]
            attr.lastGainAt = latest[attr.id]
        }
    }
}
