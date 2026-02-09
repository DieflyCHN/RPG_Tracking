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

    init(name: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
    }
}
