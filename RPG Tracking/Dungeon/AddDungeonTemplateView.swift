//
//  AddDungeonTemplateView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AddDungeonTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var usesDuration: Bool = true
    @State private var effects: [DungeonEffectDraft] = []
    @State private var showAttributePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("副本名称", text: $name)
                        .textInputAutocapitalization(.never)

                    Toggle("按时间计价", isOn: $usesDuration)
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
            }
            .navigationTitle("添加主线副本")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addTemplate()
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !effects.isEmpty
    }

    private func addEffect(attribute: RPGAttribute) {
        guard !effects.contains(where: { $0.attribute.id == attribute.id }) else { return }
        effects.append(DungeonEffectDraft(attribute: attribute, multiplier: 1))
    }

    private func removeEffect(_ effect: DungeonEffectDraft) {
        effects.removeAll { $0.id == effect.id }
    }

    private func addTemplate() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let template = DungeonTemplate(name: trimmed, usesDuration: usesDuration)
        modelContext.insert(template)

        for effect in effects {
            let templateEffect = DungeonEffectTemplate(
                attribute: effect.attribute,
                multiplier: effect.multiplier,
                template: template
            )
            template.effects.append(templateEffect)
            modelContext.insert(templateEffect)
        }
    }
}
