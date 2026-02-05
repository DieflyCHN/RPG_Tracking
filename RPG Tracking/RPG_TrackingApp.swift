//
//  RPG_TrackingApp.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

@main
struct RPG_TrackingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            AttributeGroup.self,
            RPGAttribute.self,
            DungeonTemplate.self,
            DungeonEffectTemplate.self,
            DungeonLog.self,
            DungeonEffectLog.self
        ])
    }
}
