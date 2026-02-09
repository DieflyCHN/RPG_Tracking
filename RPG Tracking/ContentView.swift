//
//  ContentView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label("计时", systemImage: "timer")
                }

            AttributesView()
                .tabItem {
                    Label("属性", systemImage: "chart.bar.xaxis")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.pie")
                }
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
                Text("预览加载失败")
            }
        }
    }
}
