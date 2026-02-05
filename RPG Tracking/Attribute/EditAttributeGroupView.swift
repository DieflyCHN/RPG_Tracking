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
                    TextField("分类名称", text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("修改分类")
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
