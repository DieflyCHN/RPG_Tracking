//
//  AddAttributeGroupView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AddAttributeGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("attribute.group_name"), text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(L("attribute.add_group_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.add")) {
                        addGroup()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addGroup() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let group = AttributeGroup(name: trimmed, sortIndex: nextGroupIndex())
        modelContext.insert(group)
    }

    private func nextGroupIndex() -> Int {
        let descriptor = FetchDescriptor<AttributeGroup>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return (all.map(\.sortIndex).max() ?? 0) + 1
    }
}

struct AddAttributeGroupView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try? ModelContainer(
            for: AttributeGroup.self,
                RPGAttribute.self,
                DungeonTemplate.self,
                DungeonEffectTemplate.self,
                DungeonLog.self,
                DungeonEffectLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        return Group {
            if let container {
                AddAttributeGroupView()
                    .modelContainer(container)
            } else {
                Text(L("preview.failed"))
            }
        }
    }
}
