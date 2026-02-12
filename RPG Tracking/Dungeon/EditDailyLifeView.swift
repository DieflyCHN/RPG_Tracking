//
//  EditDailyLifeView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct EditDailyLifeView: View {
    @Environment(\.dismiss) private var dismiss

    let item: DailyLifeItem

    @State private var name: String

    init(item: DailyLifeItem) {
        self.item = item
        _name = State(initialValue: item.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("daily.section")) {
                    TextField(L("daily.name"), text: $name)
                        .textInputAutocapitalization(.never)
                        .disabled(item.isSystemPreset)
                }
                if item.isSystemPreset {
                    Section {
                        Text(L("daily.preset.locked"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L("daily.edit_title"))
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
                    .disabled(!canSubmit || item.isSystemPreset)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        item.name = trimmed
    }
}

struct EditDailyLifeView_Previews: PreviewProvider {
    static var previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: DailyLifeItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(DailyLifeItem(name: "上厕所"))
        return container
    }()

    static var previews: some View {
        let item = DailyLifeItem(name: "上厕所")
        return EditDailyLifeView(item: item)
            .modelContainer(previewContainer)
    }
}
