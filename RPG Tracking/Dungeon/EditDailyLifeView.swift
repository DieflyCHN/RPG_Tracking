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
                Section("日常生活") {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("编辑日常生活")
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
                    .disabled(!canSubmit)
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
