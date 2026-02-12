//
//  DailyLifeItem.swift
//  RPG Tracking
//

import Foundation
import SwiftData

@Model
final class DailyLifeItem: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var systemKey: String?
    var isArchived: Bool
    var sortIndex: Int

    init(name: String, createdAt: Date = .now, systemKey: String? = nil, isArchived: Bool = false, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.systemKey = systemKey
        self.isArchived = isArchived
        self.sortIndex = sortIndex
    }
}

extension DailyLifeItem {
    var isSystemPreset: Bool { systemKey != nil }
}
