//
//  EditDungeonTemplateView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct EditDungeonTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let template: DungeonTemplate

    @State private var name: String
    @State private var usesDuration: Bool
    @State private var effects: [DungeonEffectDraft]
    @State private var showAttributePicker = false

    init(template: DungeonTemplate) {
        self.template = template
        _name = State(initialValue: template.name)
        _usesDuration = State(initialValue: template.usesDuration)
        let drafts = template.effects.compactMap { effect -> DungeonEffectDraft? in
            guard let attribute = effect.attribute else { return nil }
            return DungeonEffectDraft(attribute: attribute, multiplier: effect.multiplier)
        }
        _effects = State(initialValue: drafts)
    }

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
            .navigationTitle("编辑主线副本")
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !effects.isEmpty
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

        template.name = trimmed
        template.usesDuration = usesDuration

        for effect in template.effects {
            modelContext.delete(effect)
        }
        template.effects.removeAll()

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

