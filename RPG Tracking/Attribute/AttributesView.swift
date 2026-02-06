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
    @Query(sort: \AttributeGroup.name) private var groups: [AttributeGroup]

    @State private var showAddGroup = false
    @State private var showAddAttribute = false
    @State private var showSettings = false
    @State private var selectedGroup: AttributeGroup?
    @State private var selectedAttribute: RPGAttribute?
    @State private var pendingDeleteGroup: AttributeGroup?
    @State private var pendingDeleteAttribute: RPGAttribute?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            SwiftUI.List(groups) { group in
                DisclosureGroup {
                    if group.entries.isEmpty {
                        Text("暂无条目")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.entries.sorted(by: { $0.name < $1.name })) { attr in
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
                                    Label("删除", systemImage: "trash")
                                }
                            }
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
            .overlay {
                if groups.isEmpty {
                    Text("先创建一个分类，再添加属性。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("属性")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("添加分类") { showAddGroup = true }
                        Button("添加属性") { showAddAttribute = true }
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
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    pendingDeleteGroup = nil
                    pendingDeleteAttribute = nil
                }
                Button("删除", role: .destructive) {
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
                    Text("将删除“\(group.name)”及其所有属性。此操作无法撤销。")
                } else if let attr = pendingDeleteAttribute {
                    Text("将删除“\(attr.name)”。此操作无法撤销。")
                } else {
                    Text("此操作无法撤销。")
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
                Label("删除", systemImage: "trash")
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
