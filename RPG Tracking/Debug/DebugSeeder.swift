//
//  DebugSeeder.swift
//  RPG Tracking
//

import Foundation
import SwiftData

// Debug integration points:
// - /Users/diefly/Library/Mobile Documents/com~apple~CloudDocs/Documents/Swift_Test/RPG Tracking/RPG Tracking/ContentView.swift (calls DebugSeeder.seedIfNeeded)
// - /Users/diefly/Library/Mobile Documents/com~apple~CloudDocs/Documents/Swift_Test/RPG Tracking/RPG Tracking/Resources/en.lproj/Localizable.strings (debug.* keys)
// - /Users/diefly/Library/Mobile Documents/com~apple~CloudDocs/Documents/Swift_Test/RPG Tracking/RPG Tracking/Resources/zh-Hans.lproj/Localizable.strings (debug.* keys)

enum DebugSeeder {
    static func seedIfNeeded(in context: ModelContext) {
        // Intentionally unconditional for developer seeding.
        // Attributes
        let lang = AttributeGroup(name: L("debug.group.language"), sortIndex: 0)
        let health = AttributeGroup(name: L("debug.group.health"), sortIndex: 1)
        let mind = AttributeGroup(name: L("debug.group.mind"), sortIndex: 2)
        context.insert(lang)
        context.insert(health)
        context.insert(mind)

        let english = RPGAttribute(name: L("debug.attr.english"), baseValue: 5, weight: 1, kind: .decay, decayPerDay: 0.05, group: lang, sortIndex: 0)
        let german = RPGAttribute(name: L("debug.attr.german"), baseValue: 3, weight: 1, kind: .decay, decayPerDay: 0.05, group: lang, sortIndex: 1)
        let stamina = RPGAttribute(name: L("debug.attr.stamina"), baseValue: 6, weight: 1.2, kind: .cumulative, decayPerDay: 0, group: health, sortIndex: 0)
        let focus = RPGAttribute(name: L("debug.attr.focus"), baseValue: 4, weight: 1.1, kind: .decay, decayPerDay: 0.03, group: mind, sortIndex: 0)
        let creativity = RPGAttribute(name: L("debug.attr.creativity"), baseValue: 2, weight: 1.0, kind: .cumulative, decayPerDay: 0, group: mind, sortIndex: 1)

        lang.entries = [english, german]
        health.entries = [stamina]
        mind.entries = [focus, creativity]

        context.insert(english)
        context.insert(german)
        context.insert(stamina)
        context.insert(focus)
        context.insert(creativity)

        // Dungeons
        let read = DungeonTemplate(name: L("debug.dungeon.read"), usesDuration: true, sortIndex: 0)
        let workout = DungeonTemplate(name: L("debug.dungeon.workout"), usesDuration: true, sortIndex: 1)
        let deepWork = DungeonTemplate(name: L("debug.dungeon.deep_work"), usesDuration: false, sortIndex: 2)
        let archiveLearn = DungeonTemplate(name: L("debug.dungeon.archive.learn"), usesDuration: true, createdAt: .now, isArchived: true, sortIndex: 0)

        context.insert(read)
        context.insert(workout)
        context.insert(deepWork)
        context.insert(archiveLearn)

        let readEffect = DungeonEffectTemplate(attribute: english, multiplier: 1.0, template: read)
        let workoutEffect = DungeonEffectTemplate(attribute: stamina, multiplier: 1.2, template: workout)
        let deepWorkEffect1 = DungeonEffectTemplate(attribute: focus, multiplier: 1.5, template: deepWork)
        let deepWorkEffect2 = DungeonEffectTemplate(attribute: creativity, multiplier: 0.8, template: deepWork)

        read.effects = [readEffect]
        workout.effects = [workoutEffect]
        deepWork.effects = [deepWorkEffect1, deepWorkEffect2]

        context.insert(readEffect)
        context.insert(workoutEffect)
        context.insert(deepWorkEffect1)
        context.insert(deepWorkEffect2)

        // Daily life (custom) + archived sample
        let coffee = DailyLifeItem(name: L("debug.daily.coffee"), sortIndex: 100)
        let nap = DailyLifeItem(name: L("debug.daily.nap"), createdAt: .now, systemKey: nil, isArchived: true, sortIndex: 101)
        context.insert(coffee)
        context.insert(nap)
    }
}

