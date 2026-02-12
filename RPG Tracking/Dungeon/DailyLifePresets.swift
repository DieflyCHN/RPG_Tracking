//
//  DailyLifePresets.swift
//  RPG Tracking
//

import Foundation
import SwiftData

enum DailyLifePresets {
    static let keys: [String] = [
        "daily.preset.bathroom",
        "daily.preset.sleep",
        "daily.preset.commute",
        "daily.preset.eat",
        "daily.preset.cook",
        "daily.preset.rest",
        "daily.preset.game"
    ]

    static func ensure(in context: ModelContext) {
        let descriptor = FetchDescriptor<DailyLifeItem>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingKeys = Set(existing.compactMap { $0.systemKey })

        let maxIndex = existing.map(\.sortIndex).max() ?? 0
        var nextIndex = maxIndex + 1

        for key in keys where !existingKeys.contains(key) {
            let item = DailyLifeItem(name: L(key), systemKey: key, sortIndex: nextIndex)
            context.insert(item)
            nextIndex += 1
        }
    }
}
