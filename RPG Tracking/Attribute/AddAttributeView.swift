//
//  AddAttributeView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AddAttributeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttributeGroup.name) private var groups: [AttributeGroup]

    @State private var name: String = ""
    @State private var selectedGroupID: UUID?
    @State private var baseValueText: String = "1.0"
    @State private var weightText: String = "1.0"
    @State private var decayText: String = "0.05"
    @State private var kind: AttributeKind = .cumulative
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    var body: some View {
        NavigationStack {
            Form {
                Section(L("attribute.section.basic")) {
                    TextField(L("attribute.name"), text: $name)
                        .textInputAutocapitalization(.never)

                    Picker(L("attribute.group"), selection: $selectedGroupID) {
                        Text(L("common.please_select")).tag(UUID?.none)
                        ForEach(groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                }

                Section(L("attribute.section.config")) {
                    HStack {
                        Text(L("attribute.base_value"))
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
                        Text(L("attribute.weight"))
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

                    Picker(L("attribute.kind"), selection: $kind) {
                        ForEach(AttributeKind.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    if kind == .decay {
                        HStack {
                            Text(L("attribute.decay"))
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
            .navigationTitle(L("attribute.add_title"))
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
                    Button(L("action.add")) {
                        addAttribute()
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedGroupID != nil
    }

    private func addAttribute() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let groupID = selectedGroupID,
              let group = groups.first(where: { $0.id == groupID }) else {
            return
        }

        let baseValue = clamp(parseDouble(baseValueText), to: 1...10)
        let weight = clamp(parseDouble(weightText), to: 1...3)
        let decayPerDay = clamp(parseDouble(decayText), to: 0...1)

        let attribute = RPGAttribute(
            name: trimmed,
            baseValue: baseValue,
            weight: weight,
            kind: kind,
            decayPerDay: decayPerDay,
            group: group,
            sortIndex: nextAttributeIndex(in: group)
        )
        modelContext.insert(attribute)
    }

    private func nextAttributeIndex(in group: AttributeGroup) -> Int {
        let maxIndex = group.entries.map(\.sortIndex).max() ?? 0
        return maxIndex + 1
    }

    private func parseDouble(_ text: String) -> Double {
        Double(text) ?? 0
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
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

struct AddAttributeView_Previews: PreviewProvider {
    static var previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: AttributeGroup.self,
                RPGAttribute.self,
                DungeonTemplate.self,
                DungeonEffectTemplate.self,
                DungeonLog.self,
                DungeonEffectLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let group = AttributeGroup(name: "语言能力")
        context.insert(group)
        return container
    }()

    static var previews: some View {
        AddAttributeView()
            .modelContainer(previewContainer)
    }
}
