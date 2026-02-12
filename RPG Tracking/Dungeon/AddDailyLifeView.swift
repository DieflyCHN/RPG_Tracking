//
//  AddDailyLifeView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct AddDailyLifeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L("daily.section")) {
                    TextField(L("daily.name"), text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(L("daily.add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.add")) {
                        addItem()
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addItem() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(DailyLifeItem(name: trimmed, sortIndex: nextDailyIndex()))
    }

    private func nextDailyIndex() -> Int {
        let descriptor = FetchDescriptor<DailyLifeItem>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return (all.filter { !$0.isArchived }.map(\.sortIndex).max() ?? 0) + 1
    }
}

struct AddDailyLifeView_Previews: PreviewProvider {
    static var previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: DailyLifeItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container
    }()

    static var previews: some View {
        AddDailyLifeView()
            .modelContainer(previewContainer)
    }
}
