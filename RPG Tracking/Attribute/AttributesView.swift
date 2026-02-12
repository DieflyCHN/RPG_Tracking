//
//  AttributesView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct AttributesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AttributeGroup.sortIndex) private var groups: [AttributeGroup]

    @State private var showAddGroup = false
    @State private var showAddAttribute = false
    @State private var showSettings = false
    @State private var selectedGroup: AttributeGroup?
    @State private var selectedAttribute: RPGAttribute?
    @State private var pendingDeleteGroup: AttributeGroup?
    @State private var pendingDeleteAttribute: RPGAttribute?
    @State private var showDeleteConfirm = false
    @State private var isReordering = false

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                ForEach(groups) { group in
                    DisclosureGroup {
                        let items = group.entries.sorted(by: { $0.sortIndex < $1.sortIndex })
                        if items.isEmpty {
                            Text(L("attributes.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { attr in
                                Button {
                                    selectedAttribute = attr
                                } label: {
                                    AttributeRow(attr: attr)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDeleteAttribute = attr
                                        pendingDeleteGroup = nil
                                        showDeleteConfirm = true
                                    } label: {
                                        Label(L("action.delete"), systemImage: "trash")
                                    }
                                }
                            }
                            .onMove { source, destination in
                                moveAttributes(in: group, from: source, to: destination)
                            }
                        }
                    } label: {
                        AttributeGroupRow(group: group, onEdit: {
                            selectedGroup = group
                        }) {
                            pendingDeleteGroup = group
                            pendingDeleteAttribute = nil
                            showDeleteConfirm = true
                        }
                    }
                }
                .onMove { source, destination in
                    moveGroups(from: source, to: destination)
                }
            }
            .overlay {
                if groups.isEmpty {
                    Text(L("attributes.empty_hint"))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("attributes.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isReordering {
                        Button(L("action.done")) {
                            isReordering = false
                        }
                    } else {
                        Button(L("action.edit")) {
                            isReordering = true
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !isReordering {
                        Menu {
                            Button(L("attributes.add_group")) { showAddGroup = true }
                            Button(L("attributes.add_item")) { showAddAttribute = true }
                        } label: {
                            Image(systemName: "plus")
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }

            }
            .sheet(isPresented: $showAddGroup) {
                AddAttributeGroupView()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddAttribute) {
                AddAttributeView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedGroup) { group in
                EditAttributeGroupView(group: group)
                    .presentationDetents([.medium])
            }
            .sheet(item: $selectedAttribute) { attr in
                EditAttributeView(attribute: attr)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) {
                SettingView()
            }
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .onAppear {
                normalizeGroupOrder()
                normalizeAttributeOrder()
            }
            .onDisappear {
                // Leave edit mode when switching tabs or leaving the page.
                isReordering = false
            }
            .alert(L("action.delete_confirm"), isPresented: $showDeleteConfirm) {
                Button(L("action.cancel"), role: .cancel) {
                    pendingDeleteGroup = nil
                    pendingDeleteAttribute = nil
                }
                Button(L("action.delete"), role: .destructive) {
                    if let group = pendingDeleteGroup {
                        deleteGroup(group)
                    } else if let attr = pendingDeleteAttribute {
                        modelContext.delete(attr)
                    }
                    pendingDeleteGroup = nil
                    pendingDeleteAttribute = nil
                }
            } message: {
                if let group = pendingDeleteGroup {
                    Text(String(format: L("attributes.delete_group_confirm"), group.name))
                } else if let attr = pendingDeleteAttribute {
                    Text(String(format: L("attributes.delete_item_confirm"), attr.name))
                } else {
                    Text(L("common.irreversible"))
                }
            }
        }
    }

    private func deleteGroup(_ group: AttributeGroup) {
        for attr in group.entries {
            modelContext.delete(attr)
        }
        modelContext.delete(group)
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var updated = groups
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, group) in updated.enumerated() {
            group.sortIndex = index
        }
    }

    private func moveAttributes(in group: AttributeGroup, from source: IndexSet, to destination: Int) {
        var updated = group.entries.sorted(by: { $0.sortIndex < $1.sortIndex })
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, attr) in updated.enumerated() {
            attr.sortIndex = index
        }
    }

    private func normalizeGroupOrder() {
        guard groups.count > 1 else { return }
        let allZero = groups.allSatisfy { $0.sortIndex == 0 }
        guard allZero else { return }
        let ordered = groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for (index, group) in ordered.enumerated() {
            group.sortIndex = index
        }
    }

    private func normalizeAttributeOrder() {
        for group in groups {
            let items = group.entries
            guard items.count > 1 else { continue }
            let allZero = items.allSatisfy { $0.sortIndex == 0 }
            guard allZero else { continue }
            let ordered = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            for (index, attr) in ordered.enumerated() {
                attr.sortIndex = index
            }
        }
    }
}

private struct AttributeGroupRow: View {
    let group: AttributeGroup
    var onEdit: () -> Void
    var onRequestDelete: () -> Void

    var body: some View {
        let now = Date()
        let level = group.level(asOf: now)
        let progress = Int((group.progress(asOf: now) * 100).rounded())

        return HStack {
            Text(group.name)
            Spacer()
            Text("Lv \(level) · \(progress)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onRequestDelete()
            } label: {
                Label(L("action.delete"), systemImage: "trash")
            }
        }
    }
}

private struct AttributeRow: View {
    let attr: RPGAttribute

    var body: some View {
        let now = Date()
        let level = attr.level(asOf: now)
        let progress = Int((attr.progress(asOf: now) * 100).rounded())

        return HStack {
            Text(attr.name)
            Spacer()
            Text("Lv \(level) · \(progress)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct AttributesView_Previews: PreviewProvider {
    static var previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: AttributeGroup.self,
                RPGAttribute.self,
                DungeonTemplate.self,
                DungeonEffectTemplate.self,
                DungeonLog.self,
                DungeonEffectLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let group = AttributeGroup(name: "语言能力")
        let english = RPGAttribute(name: "英语", baseValue: 5, weight: 1, group: group)
        let german = RPGAttribute(name: "德语", baseValue: 5, weight: 1, group: group)
        group.entries = [english, german]

        context.insert(group)
        context.insert(english)
        context.insert(german)
        return container
    }()

    static var previews: some View {
        AttributesView()
            .modelContainer(previewContainer)
    }
}
