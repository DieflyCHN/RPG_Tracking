//
//  DungeonModels.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import Foundation
import SwiftData

@Model
final class DungeonTemplate: Identifiable {
    var id: UUID
    var name: String
    var usesDuration: Bool
    var createdAt: Date
    var effects: [DungeonEffectTemplate] = []

    init(name: String, usesDuration: Bool = true, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.usesDuration = usesDuration
        self.createdAt = createdAt
    }
}

@Model
final class DungeonEffectTemplate: Identifiable {
    var id: UUID
    var multiplier: Double
    var attribute: RPGAttribute?
    var template: DungeonTemplate?

    init(attribute: RPGAttribute?, multiplier: Double = 1, template: DungeonTemplate? = nil) {
        self.id = UUID()
        self.attribute = attribute
        self.multiplier = multiplier
        self.template = template
    }
}

@Model
final class DungeonLog: Identifiable {
    var id: UUID
    var name: String
    var date: Date
    var usesDuration: Bool
    var durationMinutes: Int
    var rating: Int
    var isFailed: Bool
    var rewardMultiplier: Double
    var location: String?
    var notes: String?

    var template: DungeonTemplate?
    var effects: [DungeonEffectLog] = []

    init(
        name: String,
        date: Date = .now,
        usesDuration: Bool,
        durationMinutes: Int,
        rating: Int,
        isFailed: Bool,
        rewardMultiplier: Double = 1,
        location: String? = nil,
        notes: String? = nil,
        template: DungeonTemplate? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.usesDuration = usesDuration
        self.durationMinutes = durationMinutes
        self.rating = rating
        self.isFailed = isFailed
        self.rewardMultiplier = rewardMultiplier
        self.location = location
        self.notes = notes
        self.template = template
    }

    var bonus: Double {
        if isFailed {
            let stored = UserDefaults.standard.double(forKey: "failedBonus")
            let value = stored == 0 ? 1.0 : stored
            return max(0.1, min(2.0, value))
        }
        return max(0, min(1, Double(rating) / 100))
    }

    var timeFactor: Double {
        usesDuration ? max(0, Double(durationMinutes) / 60.0) : 1
    }
}

@Model
final class DungeonEffectLog: Identifiable {
    var id: UUID
    var multiplier: Double
    var baseValueSnapshot: Double
    var earned: Double
    var attribute: RPGAttribute?
    var log: DungeonLog?

    init(
        attribute: RPGAttribute?,
        multiplier: Double = 1,
        baseValueSnapshot: Double,
        earned: Double,
        log: DungeonLog? = nil
    ) {
        self.id = UUID()
        self.attribute = attribute
        self.multiplier = multiplier
        self.baseValueSnapshot = baseValueSnapshot
        self.earned = earned
        self.log = log
    }
}
