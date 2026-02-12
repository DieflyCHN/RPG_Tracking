//
//  ContentView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label(L("tab.timer"), systemImage: "timer")
                }

            AttributesView()
                .tabItem {
                    Label(L("tab.attributes"), systemImage: "chart.bar.xaxis")
                }

            StatsView()
                .tabItem {
                    Label(L("tab.stats"), systemImage: "chart.pie")
                }
        }
        .task {
            DailyLifePresets.ensure(in: modelContext)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try? ModelContainer(
            for: AttributeGroup.self,
                RPGAttribute.self,
                DungeonTemplate.self,
                DungeonEffectTemplate.self,
                DungeonLog.self,
                DungeonEffectLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        return Group {
            if let container {
                ContentView()
                    .modelContainer(container)
            } else {
                Text(L("preview.failed"))
            }
        }
    }
}
