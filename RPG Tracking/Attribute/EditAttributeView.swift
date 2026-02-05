//
//  EditAttributeView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct EditAttributeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttributeGroup.name) private var groups: [AttributeGroup]

    let attribute: RPGAttribute

    @State private var name: String
    @State private var selectedGroupID: UUID?

    @State private var baseValue: Double
    @State private var baseWhole: Int
    @State private var baseFraction: Int

    @State private var weight: Double
    @State private var weightWhole: Int
    @State private var weightFraction: Int

    @State private var kind: AttributeKind

    @State private var decayPerDay: Double
    @State private var decayWhole: Int
    @State private var decayTenth: Int
    @State private var decayHundredth: Int

    init(attribute: RPGAttribute) {
        self.attribute = attribute

        _name = State(initialValue: attribute.name)
        _selectedGroupID = State(initialValue: attribute.group?.id)

        let clampedBase = Self.clamp(attribute.baseValue, to: 1...10)
        _baseValue = State(initialValue: clampedBase)
        let baseWhole = min(max(Int(clampedBase), 1), 10)
        let baseFraction = Int((clampedBase - Double(baseWhole)) * 10).clamped(to: 0...9)
        _baseWhole = State(initialValue: baseWhole)
        _baseFraction = State(initialValue: baseWhole == 10 ? 0 : baseFraction)

        let clampedWeight = Self.clamp(attribute.weight, to: 1...3)
        _weight = State(initialValue: clampedWeight)
        let weightWhole = min(max(Int(clampedWeight), 1), 3)
        let weightFraction = Int((clampedWeight - Double(weightWhole)) * 10).clamped(to: 0...9)
        _weightWhole = State(initialValue: weightWhole)
        _weightFraction = State(initialValue: weightWhole == 3 ? 0 : weightFraction)

        let kind = attribute.kind
        _kind = State(initialValue: kind)

        let clampedDecay = Self.clamp(attribute.decayPerDay, to: 0...1)
        _decayPerDay = State(initialValue: clampedDecay)
        let decayWhole = min(max(Int(clampedDecay), 0), 1)
        let decimal = Int(((clampedDecay - Double(decayWhole)) * 100).rounded()).clamped(to: 0...99)
        _decayWhole = State(initialValue: decayWhole)
        _decayTenth = State(initialValue: decimal / 10)
        _decayHundredth = State(initialValue: decimal % 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("属性名称", text: $name)
                        .textInputAutocapitalization(.never)

                    Picker("所属分类", selection: $selectedGroupID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                }

                Section("属性配置") {
                    BaseValueWheelRow(
                        title: "基础值（1-10）",
                        whole: $baseWhole,
                        fraction: $baseFraction
                    )

                    WheelDecimalRow(
                        title: "权重（1-3）",
                        wholeRange: 1...3,
                        whole: $weightWhole,
                        fraction: $weightFraction
                    )

                    Picker("属性类型", selection: $kind) {
                        ForEach(AttributeKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    if kind == .decay {
                        WheelTwoDecimalRow(
                            title: "每日衰减（0-1）",
                            wholeRange: 0...1,
                            whole: $decayWhole,
                            tenth: $decayTenth,
                            hundredth: $decayHundredth
                        )
                    }
                }
            }
            .navigationTitle("修改属性")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                if selectedGroupID == nil {
                    selectedGroupID = groups.first?.id
                }
            }
            .onChange(of: baseWhole) { _, newValue in
                if newValue == 10 { baseFraction = 0 }
                baseValue = Double(baseWhole) + Double(baseFraction) / 10
            }
            .onChange(of: baseFraction) { _, _ in
                if baseWhole == 10 { baseFraction = 0 }
                baseValue = Double(baseWhole) + Double(baseFraction) / 10
            }
            .onChange(of: weightWhole) { _, _ in
                if weightWhole == 3 { weightFraction = 0 }
                weight = Double(weightWhole) + Double(weightFraction) / 10
            }
            .onChange(of: weightFraction) { _, _ in
                if weightWhole == 3 { weightFraction = 0 }
                weight = Double(weightWhole) + Double(weightFraction) / 10
            }
            .onChange(of: decayWhole) { _, _ in
                if decayWhole == 1 {
                    decayTenth = 0
                    decayHundredth = 0
                }
                decayPerDay = Double(decayWhole) + Double(decayTenth) / 10 + Double(decayHundredth) / 100
            }
            .onChange(of: decayTenth) { _, _ in
                if decayWhole == 1 {
                    decayTenth = 0
                    decayHundredth = 0
                }
                decayPerDay = Double(decayWhole) + Double(decayTenth) / 10 + Double(decayHundredth) / 100
            }
            .onChange(of: decayHundredth) { _, _ in
                if decayWhole == 1 {
                    decayTenth = 0
                    decayHundredth = 0
                }
                decayPerDay = Double(decayWhole) + Double(decayTenth) / 10 + Double(decayHundredth) / 100
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedGroupID != nil
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let groupID = selectedGroupID,
              let newGroup = groups.first(where: { $0.id == groupID }) else {
            return
        }

        let oldGroup = attribute.group
        attribute.name = trimmed
        attribute.baseValue = baseValue
        attribute.weight = weight
        attribute.kind = kind
        attribute.decayPerDay = decayPerDay

        if oldGroup?.id != newGroup.id {
            if let oldGroup {
                oldGroup.entries.removeAll { $0.id == attribute.id }
            }
            if !newGroup.entries.contains(where: { $0.id == attribute.id }) {
                newGroup.entries.append(attribute)
            }
            attribute.group = newGroup
        } else if attribute.group == nil {
            // In case relationship was nil but IDs match (edge case)
            if !newGroup.entries.contains(where: { $0.id == attribute.id }) {
                newGroup.entries.append(attribute)
            }
            attribute.group = newGroup
        }
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }
}
