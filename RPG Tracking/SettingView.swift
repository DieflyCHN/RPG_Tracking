//
//  SettingView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI

struct SettingView: View {
    @AppStorage("statsHeatmapLatest") private var statsHeatmapLatest: Bool = true
    @AppStorage("statsCompactLogs") private var statsCompactLogs: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    HStack {
                        Text("统计页热力图最新：")
                        Spacer()
                        Text(statsHeatmapLatest ? "靠右" : "靠左")
                            .foregroundStyle(.secondary)
                        Toggle("", isOn: $statsHeatmapLatest)
                            .labelsHidden()
                    }

                    HStack {
                        Text("统计页紧凑布局：")
                        Spacer()
                        Toggle("", isOn: $statsCompactLogs)
                            .labelsHidden()
                    }
                }

                Section {
                    Text("""
                         版本：v1.1.0-beta
                         日期：2026.02.05
                         """)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
