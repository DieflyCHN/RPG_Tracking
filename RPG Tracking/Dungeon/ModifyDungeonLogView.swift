//
//  ModifyDungeonLogView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct ModifyDungeonLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DungeonLog.date, order: .reverse) private var logs: [DungeonLog]

    let log: DungeonLog
    private var isDailyLife: Bool { log.dailyLifeItem != nil }

    @State private var name: String
    @State private var usesDuration: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var ratingText: String
    @State private var isFailed: Bool
    @State private var rewardText: String
    @State private var location: String
    @State private var notes: String
    @State private var effects: [DungeonEffectDraft]
    @State private var effectMultiplierTexts: [UUID: String] = [:]
    @State private var showAttributePicker = false
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    init(log: DungeonLog) {
        self.log = log
        _name = State(initialValue: log.name)
        _usesDuration = State(initialValue: log.usesDuration)
        let end = log.date
        let start = end.addingTimeInterval(-Double(log.durationMinutes) * 60.0)
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
        _ratingText = State(initialValue: "\(log.rating)")
        _isFailed = State(initialValue: log.isFailed)
        _rewardText = State(initialValue: String(format: "%.1f", log.rewardMultiplier))
        _location = State(initialValue: log.location ?? "")
        _notes = State(initialValue: log.notes ?? "")

        let drafts = log.effects.compactMap { effect -> DungeonEffectDraft? in
            guard let attribute = effect.attribute else { return nil }
            return DungeonEffectDraft(attribute: attribute, multiplier: effect.multiplier)
        }
        _effects = State(initialValue: drafts)
        var initialTexts: [UUID: String] = [:]
        for draft in drafts {
            initialTexts[draft.id] = String(format: "%.1f", draft.multiplier)
        }
        _effectMultiplierTexts = State(initialValue: initialTexts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("log.section.basic")) {
                    TextField(L("log.name"), text: $name)
                        .textInputAutocapitalization(.never)

                    HStack {
                        Text(L("log.start_time"))
                        Spacer()
                        Text(DateFormatters.fullDateTime.string(from: startDate))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    if isLatestLog {
                        DatePicker(
                            L("log.end_time"),
                            selection: $endDate,
                            in: startDate...Date()
                        )
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    } else {
                        HStack {
                            Text(L("log.end_time"))
                            Spacer()
                            Text(DateFormatters.fullDateTime.string(from: endDate))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(L("log.duration"))
                        Spacer()
                        Text(formatDuration(from: startDate, to: endDate))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Text(usesDuration ? L("log.pricing.duration") : L("log.pricing.fixed"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(L("log.section.effects")) {
                    if isDailyLife {
                        Text(L("log.daily_no_effects"))
                            .foregroundStyle(.secondary)
                    } else if effects.isEmpty {
                        Text(L("log.effects.empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($effects) { $effect in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(effect.attribute.name)
                                HStack {
                                    Text(L("log.multiplier"))
                                    Spacer()
                                    TextField("1.0", text: multiplierTextBinding($effect))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .focused($focusedField, equals: .effect(effect.id))
                            }
                        }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    removeEffect(effect)
                                } label: {
                                    Label(L("action.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }

                    if !isDailyLife {
                        Button(L("log.effects.add")) {
                            showAttributePicker = true
                        }
                    }
                }

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

                Section(L("victory.optional")) {
                    TextField(L("victory.location"), text: $location)
                    TextField(L("victory.notes"), text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(L("log.edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: focusedField) { _, newValue in
                handleFocusChange(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.save")) {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
            .sheet(isPresented: $showAttributePicker) {
                AttributePickerView { attribute in
                    addEffect(attribute: attribute)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isDailyLife || !effects.isEmpty)
    }

    private func addEffect(attribute: RPGAttribute) {
        guard !effects.contains(where: { $0.attribute.id == attribute.id }) else { return }
        effects.append(DungeonEffectDraft(attribute: attribute, multiplier: 1))
    }

    private func removeEffect(_ effect: DungeonEffectDraft) {
        effects.removeAll { $0.id == effect.id }
        effectMultiplierTexts.removeValue(forKey: effect.id)
        if focusedField == .effect(effect.id) {
            focusedField = nil
        }
    }

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        applyMultiplierTexts()

        // Collect affected attributes: union of old and new.
        var seen = Set<UUID>()
        var affected: [RPGAttribute] = []
        for effect in log.effects {
            guard let attr = effect.attribute else { continue }
            if seen.insert(attr.id).inserted { affected.append(attr) }
        }
        for draft in effects {
            if seen.insert(draft.attribute.id).inserted { affected.append(draft.attribute) }
        }

        log.name = trimmed
        log.date = endDate
        log.usesDuration = usesDuration
        log.durationMinutes = durationMinutes
        if isDailyLife {
            log.rating = 0
            log.isFailed = false
            log.rewardMultiplier = 1.0
        } else {
            log.rating = ratingValue
            log.isFailed = isFailed
            log.rewardMultiplier = rewardMultiplierValue
        }
        log.location = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location
        log.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes

        // Reconcile effects.
        var existingByAttrID: [UUID: DungeonEffectLog] = [:]
        for effect in log.effects {
            if let id = effect.attribute?.id {
                existingByAttrID[id] = effect
            }
        }

        let bonus = log.bonus
        let timeFactor = log.timeFactor
        let rewardMultiplier = rewardMultiplierValue

        var keepIDs = Set<UUID>()
        if !isDailyLife {
            for draft in effects {
            let baseValue = draft.attribute.baseValue
            let earned = max(0, baseValue * draft.multiplier * timeFactor * bonus * rewardMultiplier)

            if let existing = existingByAttrID[draft.attribute.id] {
                existing.multiplier = draft.multiplier
                existing.attribute = draft.attribute
                existing.baseValueSnapshot = baseValue
                existing.earned = earned
                keepIDs.insert(existing.id)
            } else {
                let created = DungeonEffectLog(
                    attribute: draft.attribute,
                    multiplier: draft.multiplier,
                    baseValueSnapshot: baseValue,
                    earned: earned,
                    log: log
                )
                log.effects.append(created)
                modelContext.insert(created)
                keepIDs.insert(created.id)
            }
            }
        }

        // Remove effects no longer present.
        for effect in log.effects where !keepIDs.contains(effect.id) {
            modelContext.delete(effect)
        }

        // Recalculate attributes to avoid double-counting.
        AttributeRecalculator.recalculateAttributes(affected, in: modelContext)
    }

    private var rewardMultiplierValue: Double {
        let value = Double(rewardText) ?? 1.0
        return clampToOneDecimal(min(max(value, 0), 2.0))
    }

    private var ratingValue: Int {
        let value = Int(ratingText) ?? 0
        return min(max(value, 0), 100)
    }

    private var durationMinutes: Int {
        max(1, Int(endDate.timeIntervalSince(startDate) / 60.0))
    }

    private var isLatestLog: Bool {
        logs.first?.id == log.id
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60.0))
        let totalHours = Double(minutes) / 60.0
        if totalHours >= 24 {
            let days = totalHours / 24.0
            return String(format: L("stats.duration.days"), days)
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: L("stats.duration.hm"), hours, mins)
    }

    private func multiplierTextBinding(_ effect: Binding<DungeonEffectDraft>) -> Binding<String> {
        Binding(
            get: {
                if let cached = effectMultiplierTexts[effect.wrappedValue.id] {
                    return cached
                }
                let formatted = String(format: "%.1f", effect.wrappedValue.multiplier)
                effectMultiplierTexts[effect.wrappedValue.id] = formatted
                return formatted
            },
            set: { newValue in
                let filtered = filterDecimal(newValue)
                effectMultiplierTexts[effect.wrappedValue.id] = filtered
            }
        )
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

    private func applyMultiplierText(effectID: UUID) {
        guard let text = effectMultiplierTexts[effectID] else { return }
        let clamped = clampDecimalStringOrDefault(text, min: 0, max: 5.0, defaultValue: 1.0)
        if let index = effects.firstIndex(where: { $0.id == effectID }) {
            effects[index].multiplier = Double(clamped) ?? effects[index].multiplier
            effectMultiplierTexts[effectID] = clamped
        }
    }

    private func applyMultiplierTexts() {
        for index in effects.indices {
            let id = effects[index].id
            guard let text = effectMultiplierTexts[id] else { continue }
            let clamped = clampDecimalStringOrDefault(text, min: 0, max: 5.0, defaultValue: 1.0)
            effects[index].multiplier = Double(clamped) ?? effects[index].multiplier
            effectMultiplierTexts[id] = clamped
        }
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
        case .effect(let id):
            applyMultiplierText(effectID: id)
        }
        lastFocusedField = newValue
    }
}

private enum DateFormatters {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMdHHmm")
        return formatter
    }()
}

private enum FocusField: Hashable {
    case rating
    case reward
    case effect(UUID)
}
