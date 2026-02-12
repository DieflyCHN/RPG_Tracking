//
//  TimerView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DungeonLog.date, order: .reverse) private var logs: [DungeonLog]
    @Query(sort: \DungeonTemplate.name) private var templates: [DungeonTemplate]
    @Query(sort: \DailyLifeItem.name) private var dailyLifeItems: [DailyLifeItem]

    @State private var sessionStart: Date = .now
    @State private var hasAnchoredToLog = false
    @State private var selectedTemplate: DungeonTemplate?
    @State private var selectedDailyLife: DailyLifeItem?
    @State private var showTemplatePicker = false
    @State private var showVictorySheet = false
    @State private var showDungeonManage = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let remaining = dayRemaining(asOf: now)
                let elapsed = max(0, now.timeIntervalSince(sessionStart))

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: 1 - remaining.fractionRemaining)
                                .tint(.green)
                                .scaleEffect(x: 1, y: 2.0, anchor: .center)
                            Text(String(format: L("timer.today_remaining"), formatHoursMinutes(remaining.secondsRemaining)))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L("timer.duration"))
                                Spacer()
                                Text(formatDuration(elapsed))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(L("timer.start"))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(DateFormatters.monthDayTimeSeconds.string(from: sessionStart))
                                        .monospacedDigit()
                                }
                                HStack {
                                    Text(L("timer.end"))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(DateFormatters.monthDayTimeSeconds.string(from: now))
                                        .monospacedDigit()
                                }
                            }

                            HStack {
                                Text(L("timer.dungeon"))
                                Spacer()
                                Text(selectedName ?? L("timer.unselected"))
                                    .foregroundStyle(.secondary)
                                Button {
                                    showTemplatePicker = true
                                } label: {
                                    Image(systemName: hasSelection ? "gearshape" : "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }

                    Section {
                        Button {
                            showVictorySheet = true
                        } label: {
                            Text(L("timer.victory"))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.headline)
                        }
                        .disabled(!hasSelection)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(L("timer.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDungeonManage = true
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                                .accessibilityLabel(Text(L("timer.manage_dungeons")))
                        }
                    }
                }
                .sheet(isPresented: $showTemplatePicker) {
                    DungeonPickerSheet(
                        templates: templates,
                        dailyLifeItems: dailyLifeItems,
                        selectedTemplate: $selectedTemplate,
                        selectedDailyLife: $selectedDailyLife
                    )
                }
                .sheet(isPresented: $showVictorySheet) {
                    VictorySheet(onConfirm: { result in
                        saveLog(
                            endAt: now,
                            elapsedSeconds: elapsed,
                            rating: result.rating,
                            isFailed: result.isFailed,
                            rewardMultiplier: result.rewardMultiplier,
                            location: result.location,
                            notes: result.notes
                        )
                    }, isDailyLife: selectedDailyLife != nil)
                }
                .sheet(isPresented: $showDungeonManage) {
                    DungeonsView()
                }
            }
            .onAppear {
                // Soft "always-on": anchor to the latest log end whenever entering the timer page.
                if let lastEnd = logs.first?.date {
                    sessionStart = lastEnd
                    hasAnchoredToLog = true
                } else {
                    sessionStart = Date()
                    hasAnchoredToLog = false
                }
            }
            .onChange(of: logs.first?.date) { _, newValue in
                // First launch: @Query may populate after onAppear. Anchor once when the first log arrives.
                guard !hasAnchoredToLog, let newValue else { return }
                sessionStart = newValue
                hasAnchoredToLog = true
            }
        }
    }

    private func saveLog(
        endAt: Date,
        elapsedSeconds: TimeInterval,
        rating: Int,
        isFailed: Bool,
        rewardMultiplier: Double,
        location: String?,
        notes: String?
    ) {
        guard let selection = currentSelection else { return }
        let durationMinutes = max(1, Int((elapsedSeconds / 60.0).rounded()))

        switch selection {
        case .template(let template):
            let log = DungeonLog(
                name: template.name,
                date: endAt,
                usesDuration: template.usesDuration,
                durationMinutes: durationMinutes,
                rating: rating,
                isFailed: isFailed,
                rewardMultiplier: rewardMultiplier,
                location: location,
                notes: notes,
                template: template,
                dailyLifeItem: nil
            )
            modelContext.insert(log)

            let bonus = log.bonus
            let timeFactor = log.timeFactor

            for effect in template.effects {
                guard let attribute = effect.attribute else { continue }
                let baseValue = attribute.baseValue
                let earned = max(0, baseValue * effect.multiplier * timeFactor * bonus * rewardMultiplier)

                if earned > 0 {
                    attribute.applyGain(earned, asOf: endAt)
                }

                let logEffect = DungeonEffectLog(
                    attribute: attribute,
                    multiplier: effect.multiplier,
                    baseValueSnapshot: baseValue,
                    earned: earned,
                    log: log
                )
                log.effects.append(logEffect)
                modelContext.insert(logEffect)
            }
        case .dailyLife(let item):
            let log = DungeonLog(
                name: item.name,
                date: endAt,
                usesDuration: true,
                durationMinutes: durationMinutes,
                rating: 0,
                isFailed: false,
                rewardMultiplier: 1.0,
                location: location,
                notes: notes,
                template: nil,
                dailyLifeItem: item
            )
            modelContext.insert(log)
        }

        sessionStart = endAt
        hasAnchoredToLog = true
        selectedTemplate = nil
        selectedDailyLife = nil
        showVictorySheet = false
    }

    private var hasSelection: Bool {
        selectedTemplate != nil || selectedDailyLife != nil
    }

    private var selectedName: String? {
        if let template = selectedTemplate { return template.name }
        if let item = selectedDailyLife { return item.name }
        return nil
    }

    private var currentSelection: TimerSelection? {
        if let template = selectedTemplate { return .template(template) }
        if let item = selectedDailyLife { return .dailyLife(item) }
        return nil
    }

    private func dayRemaining(asOf now: Date) -> (secondsRemaining: TimeInterval, fractionRemaining: Double) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        let secondsTotal = nextDay.timeIntervalSince(startOfDay)
        let secondsRemaining = max(0, nextDay.timeIntervalSince(now))
        let fractionRemaining = secondsTotal > 0 ? (secondsRemaining / secondsTotal) : 0
        return (secondsRemaining, fractionRemaining)
    }

    private func formatHoursMinutes(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

private struct DungeonPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [DungeonTemplate]
    let dailyLifeItems: [DailyLifeItem]
    @Binding var selectedTemplate: DungeonTemplate?
    @Binding var selectedDailyLife: DailyLifeItem?

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty && dailyLifeItems.isEmpty {
                    Text(L("timer.picker.empty"))
                        .foregroundStyle(.secondary)
                }

                Section(L("timer.picker.main_section")) {
                    if templates.isEmpty {
                        Text(L("timer.picker.main_empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates) { template in
                            Button {
                                selectedTemplate = template
                                selectedDailyLife = nil
                                dismiss()
                            } label: {
                                HStack {
                                    Text(template.name)
                                    Spacer()
                                    if selectedTemplate?.id == template.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }

                Section(L("timer.picker.daily_section")) {
                    if dailyLifeItems.isEmpty {
                        Text(L("timer.picker.daily_empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dailyLifeItems) { item in
                            Button {
                                selectedDailyLife = item
                                selectedTemplate = nil
                                dismiss()
                            } label: {
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    if selectedDailyLife?.id == item.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle(L("timer.picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.close")) { dismiss() }
                }
            }
        }
    }
}

private enum TimerSelection {
    case template(DungeonTemplate)
    case dailyLife(DailyLifeItem)
}

private struct VictoryResult {
    let rating: Int
    let isFailed: Bool
    let rewardMultiplier: Double
    let location: String?
    let notes: String?
}

private struct VictorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var onConfirm: (VictoryResult) -> Void
    var isDailyLife: Bool = false

    @State private var isFailed = false
    @State private var ratingText: String = "80"
    @State private var rewardWhole: Int = 1
    @State private var rewardText: String = "1.0"
    @State private var location = ""
    @State private var notes = ""
    @State private var showOptionalInfo = false
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    var body: some View {
        NavigationStack {
            List {
                if !isDailyLife {
                    Section(L("victory.section.rating")) {
                        Toggle(L("victory.toggle.failed"), isOn: $isFailed)
                            .onChange(of: isFailed) { _, newValue in
                                if newValue {
                                    focusedField = nil
                                    ratingText = "0"
                                }
                            }

                        if !isFailed {
                            HStack {
                                Text(L("victory.rating"))
                                Spacer()
                                TextField("0-100", text: $ratingText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .focused($focusedField, equals: .rating)
                            }
                            .onChange(of: ratingText) { _, newValue in
                                ratingText = newValue.filter { $0.isNumber }
                            }

                            HStack {
                                Text(L("victory.reward"))
                                Spacer()
                                TextField("1.0", text: $rewardText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .focused($focusedField, equals: .reward)
                            }
                            .onChange(of: rewardText) { _, newValue in
                                let filtered = filterDecimal(newValue)
                                rewardText = filtered
                            }
                        }
                    }
                }

                Section {
                    DisclosureGroup(L("victory.optional"), isExpanded: $showOptionalInfo) {
                        TextField(L("victory.location"), text: $location)
                        TextField(L("victory.notes"), text: $notes, axis: .vertical)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("victory.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: focusedField) { _, newValue in
                handleFocusChange(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.save")) {
                        onConfirm(
                            VictoryResult(
                                rating: ratingValue,
                                isFailed: isFailed,
                                rewardMultiplier: rewardMultiplierValue,
                                location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var ratingValue: Int {
        if isDailyLife { return 0 }
        let value = Int(ratingText) ?? 0
        return min(max(value, 0), 100)
    }

    private var rewardMultiplierValue: Double {
        if isDailyLife { return 1.0 }
        let value = Double(rewardText) ?? 1.0
        return clampToOneDecimal(min(max(value, 0), 2.0))
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

    private func clampToOneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10.0
    }

    private func clampIntStringOrDefault(_ text: String, min: Int, max: Int, defaultValue: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else { return String(defaultValue) }
        return String(Swift.min(Swift.max(value, min), max))
    }

    private func clampDecimalStringOrDefault(_ text: String, min: Double, max: Double, defaultValue: Double) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." {
            return String(format: "%.1f", clampToOneDecimal(defaultValue))
        }
        if trimmed.hasSuffix(".") { return trimmed }
        guard let value = Double(trimmed) else {
            return String(format: "%.1f", clampToOneDecimal(defaultValue))
        }
        let clamped = Swift.min(Swift.max(value, min), max)
        return String(format: "%.1f", clampToOneDecimal(clamped))
    }

    private func handleFocusChange(_ newValue: FocusField?) {
        guard let last = lastFocusedField, last != newValue else {
            lastFocusedField = newValue
            return
        }
        if isDailyLife {
            lastFocusedField = newValue
            return
        }
        switch last {
        case .rating:
            ratingText = clampIntStringOrDefault(ratingText, min: 0, max: 100, defaultValue: 0)
        case .reward:
            rewardText = clampDecimalStringOrDefault(rewardText, min: 0, max: 2.0, defaultValue: 1.0)
        }
        lastFocusedField = newValue
    }
}

private enum DateFormatters {
    static let monthDayTimeSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMdHHmmss")
        return formatter
    }()
}

private enum FocusField: Hashable {
    case rating
    case reward
}
