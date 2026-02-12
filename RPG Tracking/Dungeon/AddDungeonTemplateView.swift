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
                Section(L("dungeon.section.basic")) {
                    TextField(L("dungeon.name"), text: $name)
                        .textInputAutocapitalization(.never)

                    Toggle(L("dungeon.uses_duration"), isOn: $usesDuration)
                }

                Section(L("dungeon.section.effects")) {
                    if effects.isEmpty {
                        Text(L("dungeon.effects.empty"))
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
                                    Label(L("action.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button(L("dungeon.effects.add")) {
                        showAttributePicker = true
                    }
                }
            }
            .navigationTitle(L("dungeon.add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.add")) {
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

        let template = DungeonTemplate(name: trimmed, usesDuration: usesDuration, sortIndex: nextTemplateIndex())
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

    private func nextTemplateIndex() -> Int {
        let descriptor = FetchDescriptor<DungeonTemplate>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return (all.filter { !$0.isArchived }.map(\.sortIndex).max() ?? 0) + 1
    }
}
