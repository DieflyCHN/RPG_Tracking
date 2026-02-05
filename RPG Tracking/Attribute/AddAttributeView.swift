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
    @State private var baseValue: Double = 1
    @State private var baseWhole: Int = 1
    @State private var baseFraction: Int = 0
    @State private var weightWhole: Int = 1
    @State private var weightFraction: Int = 0
    @State private var decayWhole: Int = 0
    @State private var decayTenth: Int = 0
    @State private var decayHundredth: Int = 5
    @State private var weight: Double = 1
    @State private var kind: AttributeKind = .cumulative
    @State private var decayPerDay: Double = 0.05

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
            .navigationTitle("添加属性")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
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
                let clampedBase = clamp(baseValue, to: 1...10)
                baseValue = clampedBase
                let whole = min(max(Int(clampedBase), 1), 10)
                let fraction = Int((clampedBase - Double(whole)) * 10).clamped(to: 0...9)
                baseWhole = whole
                baseFraction = whole == 10 ? 0 : fraction

                let clampedWeight = clamp(weight, to: 1...3)
                weight = clampedWeight
                weightWhole = min(max(Int(clampedWeight), 1), 3)
                weightFraction = Int((clampedWeight - Double(weightWhole)) * 10).clamped(to: 0...9)

                let clampedDecay = clamp(decayPerDay, to: 0...1)
                decayPerDay = clampedDecay
                decayWhole = min(max(Int(clampedDecay), 0), 1)
                let decimal = Int(((clampedDecay - Double(decayWhole)) * 100).rounded()).clamped(to: 0...99)
                decayTenth = decimal / 10
                decayHundredth = decimal % 10
            }
            .onChange(of: baseWhole) { _, newValue in
                if newValue == 10 {
                    baseFraction = 0
                }
                baseValue = Double(baseWhole) + Double(baseFraction) / 10
            }
            .onChange(of: baseFraction) { _, _ in
                if baseWhole == 10 {
                    baseFraction = 0
                }
                baseValue = Double(baseWhole) + Double(baseFraction) / 10
            }
            .onChange(of: weightWhole) { _, _ in
                if weightWhole == 3 {
                    weightFraction = 0
                }
                weight = Double(weightWhole) + Double(weightFraction) / 10
            }
            .onChange(of: weightFraction) { _, _ in
                if weightWhole == 3 {
                    weightFraction = 0
                }
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedGroupID != nil
    }

    private func addAttribute() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let groupID = selectedGroupID,
              let group = groups.first(where: { $0.id == groupID }) else {
            return
        }

        let attribute = RPGAttribute(
            name: trimmed,
            baseValue: baseValue,
            weight: weight,
            kind: kind,
            decayPerDay: decayPerDay,
            group: group
        )
        modelContext.insert(attribute)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct NumericInputRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let precision: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            TextField("", value: $value, format: .number.precision(.fractionLength(precision)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, newValue in
                    let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                    if clamped != newValue {
                        value = clamped
                    }
                }

            HStack(spacing: 8) {
                Button {
                    value = min(max(value - step, range.lowerBound), range.upperBound)
                } label: {
                    Image(systemName: "minus.circle")
                }
                Button {
                    value = min(max(value + step, range.lowerBound), range.upperBound)
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct BaseValueWheelRow: View {
    let title: String
    @Binding var whole: Int
    @Binding var fraction: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(1...10, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 90)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $fraction) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 90)
                .clipped()
            }
        }
    }
}

private struct WheelDecimalRow: View {
    let title: String
    let wholeRange: ClosedRange<Int>
    @Binding var whole: Int
    @Binding var fraction: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(Array(wholeRange), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 90)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $fraction) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 90)
                .clipped()
            }
        }
    }
}

private struct WheelTwoDecimalRow: View {
    let title: String
    let wholeRange: ClosedRange<Int>
    @Binding var whole: Int
    @Binding var tenth: Int
    @Binding var hundredth: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $whole) {
                    ForEach(Array(wholeRange), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 90)
                .clipped()

                Text(".")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.primary)
                    .frame(width: 10)
                    .zIndex(1)

                Picker("", selection: $tenth) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 90)
                .clipped()

                Picker("", selection: $hundredth) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 90)
                .clipped()
            }
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
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
