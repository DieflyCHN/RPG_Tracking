//
//  DungeonEffectDraft.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import Foundation

struct DungeonEffectDraft: Identifiable {
    let id = UUID()
    var attribute: RPGAttribute
    var multiplier: Double
}
