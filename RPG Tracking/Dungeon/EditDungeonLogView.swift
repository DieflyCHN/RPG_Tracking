//
//  EditDungeonLogView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct EditDungeonLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let log: DungeonLog

    @State private var name: String
    @State private var date: Date
    @State private var usesDuration: Bool
    @State private var durationMinutes: Int
    @State private var rating: Int
    @State private var isFailed: Bool
    @State private var rewardWhole: Int
    @State private var rewardFraction: Int
    @State private var location: String
    @State private var notes: String
    @State private var effects: [DungeonEffectDraft]
    @State private var showAttributePicker = false

    init(log: DungeonLog) {
        self.log = log
        _name = State(initialValue: log.name)
        _date = State(initialValue: log.date)
        _usesDuration = State(initialValue: log.usesDuration)
        _durationMinutes = State(initialValue: log.durationMinutes)
        _rating = State(initialValue: log.rating)
        _isFailed = State(initialValue: log.isFailed)
        let rewardWhole = Int(log.rewardMultiplier)
        let rewardFraction = Int((log.rewardMultiplier * 10).rounded()) % 10
        _rewardWhole = State(initialValue: rewardWhole)
        _rewardFraction = State(initialValue: rewardFraction)
        _location = State(initialValue: log.location ?? "")
        _notes = State(initialValue: log.notes ?? "")

        let drafts = log.effects.compactMap { effect -> DungeonEffectDraft? in
            guard let attribute = effect.attribute else { return nil }
            return DungeonEffectDraft(attribute: attribute, multiplier: effect.multiplier)
        }
        _effects = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("记录名称", text: $name)
                        .textInputAutocapitalization(.never)

                    DatePicker("时间", selection: $date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))

                    WheelIntRow(title: "持续时间（分钟）", range: 1...480, value: $durationMinutes)

                    Text(usesDuration ? "计价方式：按时间" : "计价方式：固定倍率")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("影响属性") {
                    if effects.isEmpty {
                        Text("暂无影响属性")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($effects) { $effect in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(effect.attribute.name)
                                WheelDecimalRow(
                                    title: "倍率",
                                    wholeRange: 0...5,
                                    whole: effectWholeBinding($effect),
                                    fraction: effectFractionBinding($effect)
                                )
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    removeEffect(effect)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button("添加影响属性") {
                        showAttributePicker = true
                    }
                }

                Section("评分与结果") {
                    Toggle("未达到预期", isOn: $isFailed)
                        .onChange(of: isFailed) { _, newValue in
                            if newValue { rating = 0 }
                        }

                    WheelIntRow(title: "主观评分", range: 0...100, value: $rating)
                        .disabled(isFailed)

                    WheelDecimalRow(
                        title: "奖励倍数",
                        wholeRange: 0...5,
                        whole: $rewardWhole,
                        fraction: $rewardFraction
                    )
                }

                Section("可选信息") {
                    TextField("地点", text: $location)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("修改记录")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
            && durationMinutes > 0
            && !effects.isEmpty
    }

    private func addEffect(attribute: RPGAttribute) {
        guard !effects.contains(where: { $0.attribute.id == attribute.id }) else { return }
        effects.append(DungeonEffectDraft(attribute: attribute, multiplier: 1))
    }

    private func removeEffect(_ effect: DungeonEffectDraft) {
        effects.removeAll { $0.id == effect.id }
    }

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

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
        log.date = date
        log.usesDuration = usesDuration
        log.durationMinutes = durationMinutes
        log.rating = rating
        log.isFailed = isFailed
        log.rewardMultiplier = rewardMultiplierValue
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

        // Remove effects no longer present.
        for effect in log.effects where !keepIDs.contains(effect.id) {
            modelContext.delete(effect)
        }

        // Recalculate attributes to avoid double-counting.
        AttributeRecalculator.recalculateAttributes(affected, in: modelContext)
    }

    private var rewardMultiplierValue: Double {
        Double(rewardWhole) + Double(rewardFraction) / 10.0
    }

    private func effectWholeBinding(_ effect: Binding<DungeonEffectDraft>) -> Binding<Int> {
        Binding(
            get: { Int(effect.wrappedValue.multiplier) },
            set: { newWhole in
                let fraction = effectFractionValue(effect.wrappedValue.multiplier)
                effect.wrappedValue.multiplier = Double(newWhole) + fraction
            }
        )
    }

    private func effectFractionBinding(_ effect: Binding<DungeonEffectDraft>) -> Binding<Int> {
        Binding(
            get: { Int((effect.wrappedValue.multiplier * 10).rounded()) % 10 },
            set: { newFraction in
                let whole = Int(effect.wrappedValue.multiplier)
                effect.wrappedValue.multiplier = Double(whole) + Double(newFraction) / 10.0
            }
        )
    }

    private func effectFractionValue(_ multiplier: Double) -> Double {
        Double(Int((multiplier * 10).rounded()) % 10) / 10.0
    }
}
