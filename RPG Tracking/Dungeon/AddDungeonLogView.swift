//
//  AddDungeonLogView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AddDungeonLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let template: DungeonTemplate?

    @State private var name: String
    @State private var date: Date
    @State private var usesDuration: Bool
    @State private var durationMinutes: Int
    @State private var rating: Double
    @State private var isFailed: Bool
    @State private var rewardMultiplier: Double
    @State private var location: String
    @State private var notes: String
    @State private var effects: [DungeonEffectDraft]
    @State private var showAttributePicker = false

    init(template: DungeonTemplate?) {
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _date = State(initialValue: .now)
        _usesDuration = State(initialValue: template?.usesDuration ?? false)
        _durationMinutes = State(initialValue: 60)
        _rating = State(initialValue: 80)
        _isFailed = State(initialValue: false)
        _rewardMultiplier = State(initialValue: 1)
        _location = State(initialValue: "")
        _notes = State(initialValue: "")
        if let template {
            let drafts = template.effects.compactMap { effect -> DungeonEffectDraft? in
                guard let attribute = effect.attribute else { return nil }
                return DungeonEffectDraft(attribute: attribute, multiplier: effect.multiplier)
            }
            _effects = State(initialValue: drafts)
        } else {
            _effects = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("记录名称", text: $name)
                        .textInputAutocapitalization(.never)

                    DatePicker("时间", selection: $date)

                    TextField("持续时间（分钟）", value: $durationMinutes, format: .number)
                        .keyboardType(.numberPad)

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
                                HStack {
                                    Text(effect.attribute.name)
                                    Spacer()
                                    Text(String(format: "x%.2f", effect.multiplier))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                Stepper("", value: $effect.multiplier, in: 0...5, step: 0.1)
                                    .labelsHidden()
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

                    HStack {
                        Text("主观评分")
                        Spacer()
                        Text("\(Int(rating.rounded()))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $rating, in: 0...100, step: 1)
                        .disabled(isFailed)

                    HStack {
                        Text("奖励倍数")
                        Spacer()
                        Text(String(format: "x%.2f", rewardMultiplier))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Stepper("", value: $rewardMultiplier, in: 0...5, step: 0.1)
                        .labelsHidden()
                }

                Section("可选信息") {
                    TextField("地点", text: $location)
                    TextField("备注", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(template == nil ? "记录支线副本" : "记录副本")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveLog()
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

    private func saveLog() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let log = DungeonLog(
            name: trimmed,
            date: date,
            usesDuration: usesDuration,
            durationMinutes: durationMinutes,
            rating: Int(rating.rounded()),
            isFailed: isFailed,
            rewardMultiplier: rewardMultiplier,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            template: template
        )
        modelContext.insert(log)

        let timeFactor = log.timeFactor
        let bonus = log.bonus

        for effect in effects {
            let baseValue = effect.attribute.baseValue
            let earned = max(0, baseValue * effect.multiplier * timeFactor * bonus * rewardMultiplier)

            if earned > 0 {
                effect.attribute.applyGain(earned, asOf: date)
            }

            let logEffect = DungeonEffectLog(
                attribute: effect.attribute,
                multiplier: effect.multiplier,
                baseValueSnapshot: baseValue,
                earned: earned,
                log: log
            )
            log.effects.append(logEffect)
            modelContext.insert(logEffect)
        }
    }
}
