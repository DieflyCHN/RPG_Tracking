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

    @State private var baseValueText: String
    @State private var weightText: String

    @State private var kind: AttributeKind

    @State private var decayText: String
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    init(attribute: RPGAttribute) {
        self.attribute = attribute

        _name = State(initialValue: attribute.name)
        _selectedGroupID = State(initialValue: attribute.group?.id)

        let clampedBase = Self.clamp(attribute.baseValue, to: 1...10)
        _baseValueText = State(initialValue: String(format: "%.1f", clampedBase))

        let clampedWeight = Self.clamp(attribute.weight, to: 1...3)
        _weightText = State(initialValue: String(format: "%.1f", clampedWeight))

        let kind = attribute.kind
        _kind = State(initialValue: kind)

        let clampedDecay = Self.clamp(attribute.decayPerDay, to: 0...1)
        _decayText = State(initialValue: String(format: "%.2f", clampedDecay))
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
                    HStack {
                        Text("基础值（1-10）")
                        Spacer()
                        TextField("1.0", text: $baseValueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .focused($focusedField, equals: .baseValue)
                    }
                    .onChange(of: baseValueText) { _, newValue in
                        baseValueText = filterDecimal(newValue)
                    }

                    HStack {
                        Text("权重（1-3）")
                        Spacer()
                        TextField("1.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .focused($focusedField, equals: .weight)
                    }
                    .onChange(of: weightText) { _, newValue in
                        weightText = filterDecimal(newValue)
                    }

                    Picker("属性类型", selection: $kind) {
                        ForEach(AttributeKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    if kind == .decay {
                        HStack {
                            Text("每日衰减（0-1）")
                            Spacer()
                            TextField("0.05", text: $decayText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                .focused($focusedField, equals: .decay)
                        }
                        .onChange(of: decayText) { _, newValue in
                            decayText = filterDecimal(newValue)
                        }
                    }
                }
            }
            .navigationTitle("修改属性")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: focusedField) { _, newValue in
                handleFocusChange(newValue)
            }
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
        attribute.baseValue = Self.clamp(parseDouble(baseValueText), to: 1...10)
        attribute.weight = Self.clamp(parseDouble(weightText), to: 1...3)
        attribute.kind = kind
        attribute.decayPerDay = Self.clamp(parseDouble(decayText), to: 0...1)

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

    private func parseDouble(_ text: String) -> Double {
        Double(text) ?? 0
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

    private func clampDecimalStringOrDefault(_ text: String, min: Double, max: Double, fractionDigits: Int, defaultValue: Double) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." {
            return formatDecimal(defaultValue, fractionDigits: fractionDigits)
        }
        if trimmed.hasSuffix(".") { return trimmed }
        guard let value = Double(trimmed) else {
            return formatDecimal(defaultValue, fractionDigits: fractionDigits)
        }
        let clamped = Swift.min(Swift.max(value, min), max)
        return formatDecimal(clamped, fractionDigits: fractionDigits)
    }

    private func formatDecimal(_ value: Double, fractionDigits: Int) -> String {
        let format = "%.\(fractionDigits)f"
        return String(format: format, value)
    }

    private func handleFocusChange(_ newValue: FocusField?) {
        guard let last = lastFocusedField, last != newValue else {
            lastFocusedField = newValue
            return
        }
        switch last {
        case .baseValue:
            baseValueText = clampDecimalStringOrDefault(baseValueText, min: 1, max: 10, fractionDigits: 1, defaultValue: 1.0)
        case .weight:
            weightText = clampDecimalStringOrDefault(weightText, min: 1, max: 3, fractionDigits: 1, defaultValue: 1.0)
        case .decay:
            decayText = clampDecimalStringOrDefault(decayText, min: 0, max: 1, fractionDigits: 2, defaultValue: 0.05)
        }
        lastFocusedField = newValue
    }
}

private enum FocusField: Hashable {
    case baseValue
    case weight
    case decay
}
