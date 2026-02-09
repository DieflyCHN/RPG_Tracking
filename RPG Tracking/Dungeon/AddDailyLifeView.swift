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
                Section("日常生活") {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("添加日常生活")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
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
        modelContext.insert(DailyLifeItem(name: trimmed))
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
