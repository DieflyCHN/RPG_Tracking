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
    @AppStorage("failedBonus") private var failedBonus: Double = 1.0
    @State private var failedBonusText: String = "1.0"
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    var body: some View {
        NavigationStack {
            List {
                Section(L("settings.section.appearance")) {
                    HStack {
                        Text(L("settings.stats_heatmap_latest"))
                        Spacer()
                        Text(statsHeatmapLatest ? L("settings.align_right") : L("settings.align_left"))
                            .foregroundStyle(.secondary)
                        Toggle("", isOn: $statsHeatmapLatest)
                            .labelsHidden()
                    }

                    HStack {
                        Text(L("settings.stats_compact"))
                        Spacer()
                        Toggle("", isOn: $statsCompactLogs)
                            .labelsHidden()
                    }
                }

                Section(L("settings.section.settlement")) {
                    HStack {
                        Text(L("settings.failed_bonus"))
                        Spacer()
                        TextField("1.0", text: $failedBonusText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .failedBonus)
                    }
                    .onChange(of: failedBonusText) { _, newValue in
                        let filtered = filterDecimal(newValue)
                        failedBonusText = filtered
                    }
                }

                Section(L("settings.section.dev")) {
                    Button(L("settings.dev.seed")) {
                        DebugSeeder.seedIfNeeded(in: modelContext)
                    }
                }

                Section {
                    Text(String(format: L("settings.version_date"), "v3.0.0-beta", "2026.02.12"))
                }
            }
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: focusedField) { _, newValue in
                handleFocusChange(newValue)
            }
            .onAppear {
                let value = failedBonus == 0 ? 1.0 : failedBonus
                let clamped = max(0.1, min(2.0, value))
                failedBonusText = String(format: "%.1f", clamped)
                updateFailedBonus()
            }
        }
    }

    private func updateFailedBonus() {
        let parsed = Double(failedBonusText) ?? 1.0
        let clamped = min(max(parsed, 0.1), 2.0)
        failedBonus = clamped
    }

    private func filterDecimal(_ text: String) -> String {
        var result = ""
        var hasDot = false
        for char in text where char.isNumber || char == "." {
            if char == "." {
                if hasDot { continue }
                hasDot = true
            }
            result.append(char)
        }
        return result
    }

    private func clampDecimalStringOrDefault(_ text: String, min: Double, max: Double, defaultValue: Double) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." {
            return String(format: "%.1f", defaultValue)
        }
        if trimmed.hasSuffix(".") { return trimmed }
        guard let value = Double(trimmed) else {
            return String(format: "%.1f", defaultValue)
        }
        let clamped = Swift.min(Swift.max(value, min), max)
        return String(format: "%.1f", clamped)
    }

    private func handleFocusChange(_ newValue: FocusField?) {
        guard let last = lastFocusedField, last != newValue else {
            lastFocusedField = newValue
            return
        }
        switch last {
        case .failedBonus:
            failedBonusText = clampDecimalStringOrDefault(failedBonusText, min: 0.1, max: 2.0, defaultValue: 1.0)
            updateFailedBonus()
        }
        lastFocusedField = newValue
    }
}

private enum FocusField: Hashable {
    case failedBonus
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
