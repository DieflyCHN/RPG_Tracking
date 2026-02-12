//
//  EditAttributeGroupView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct EditAttributeGroupView: View {
    @Environment(\.dismiss) private var dismiss

    let group: AttributeGroup

    @State private var name: String

    init(group: AttributeGroup) {
        self.group = group
        _name = State(initialValue: group.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("attribute.group_name"), text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(L("attribute.edit_group_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.save")) {
                        save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        group.name = trimmed
    }
}
