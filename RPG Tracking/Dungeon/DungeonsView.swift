//
//  DungeonsView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

struct DungeonsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DungeonTemplate> { !$0.isArchived }, sort: \DungeonTemplate.sortIndex) private var templates: [DungeonTemplate]
    @Query(sort: \DungeonLog.date, order: .reverse) private var logs: [DungeonLog]
    @Query(filter: #Predicate<DailyLifeItem> { !$0.isArchived }, sort: \DailyLifeItem.sortIndex) private var dailyLifeItems: [DailyLifeItem]

    @State private var showAddTemplate = false
    @State private var showAddDailyLife = false
    @State private var showArchive = false
    @State private var selectedTemplate: DungeonTemplate?
    @State private var selectedDailyLife: DailyLifeItem?
    @State private var pendingDeleteTemplate: DungeonTemplate?
    @State private var pendingDeleteDailyLife: DailyLifeItem?
    @State private var showDeleteConfirm = false
    @State private var archiveAction: ArchiveAction?
    @AppStorage("dungeonExpandMain") private var expandMain = true
    @AppStorage("dungeonExpandDaily") private var expandDaily = false
    @State private var isReordering = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DisclosureGroup(isExpanded: $expandMain) {
                        if templates.isEmpty {
                            Text(L("dungeon.main_empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(templates) { template in
                                Button {
                                    selectedTemplate = template
                                } label: {
                                    DungeonTemplateRow(template: template)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        archiveAction = .archiveTemplate(template)
                                    } label: {
                                        Label(L("action.archive"), systemImage: "archivebox")
                                    }
                                    .tint(Color(red: 0.40, green: 0.46, blue: 0.86))
                                    Button(role: .destructive) {
                                        pendingDeleteTemplate = template
                                        showDeleteConfirm = true
                                    } label: {
                                        Label(L("action.delete"), systemImage: "trash")
                                    }
                                }
                            }
                            .onMove(perform: moveTemplates)
                        }
                    } label: {
                        Text(L("dungeon.main_section"))
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $expandDaily) {
                        if dailyLifeItems.isEmpty {
                            Text(L("daily.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dailyLifeItems) { item in
                                Button {
                                    selectedDailyLife = item
                                } label: {
                                    DailyLifeRow(item: item)
                                }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if !item.isSystemPreset {
                                        Button {
                                            archiveAction = .archiveDaily(item)
                                        } label: {
                                            Label(L("action.archive"), systemImage: "archivebox")
                                        }
                                        .tint(Color(red: 0.40, green: 0.46, blue: 0.86))
                                        Button(role: .destructive) {
                                            pendingDeleteDailyLife = item
                                            pendingDeleteTemplate = nil
                                            showDeleteConfirm = true
                                        } label: {
                                        Label(L("action.delete"), systemImage: "trash")
                                    }
                                    }
                                }
                            }
                            .onMove(perform: moveDailyLife)
                        }
                    } label: {
                        Text(L("daily.section"))
                    }
                }
            }
            .navigationTitle(L("dungeon.title"))
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
                        Button {
                            showArchive = true
                        } label: {
                            Image(systemName: "archivebox")
                        }

                        Menu {
                            Button(L("dungeon.add_main")) { showAddTemplate = true }
                            Button(L("daily.add")) { showAddDailyLife = true }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTemplate) {
                AddDungeonTemplateView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddDailyLife) {
                AddDailyLifeView()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showArchive) {
                ArchivedDungeonsView()
            }
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .sheet(item: $selectedTemplate) { template in
                EditDungeonTemplateView(template: template)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedDailyLife) { item in
                EditDailyLifeView(item: item)
                    .presentationDetents([.medium])
            }
            .onAppear {
                normalizeTemplateOrder()
                normalizeDailyLifeOrder()
            }
            .onDisappear {
                // Leave edit mode when switching tabs or leaving the page.
                isReordering = false
            }
            .alert(L("action.delete_confirm"), isPresented: $showDeleteConfirm) {
                Button(L("action.cancel"), role: .cancel) {
                    pendingDeleteTemplate = nil
                    pendingDeleteDailyLife = nil
                }
                Button(L("action.delete"), role: .destructive) {
                    if let template = pendingDeleteTemplate {
                        deleteTemplate(template)
                    } else if let item = pendingDeleteDailyLife {
                        modelContext.delete(item)
                    }
                    pendingDeleteTemplate = nil
                    pendingDeleteDailyLife = nil
                }
            } message: {
                if let template = pendingDeleteTemplate {
                    Text(String(format: L("dungeon.delete_main_confirm"), template.name))
                } else if let item = pendingDeleteDailyLife {
                    Text(String(format: L("daily.delete_confirm"), item.name))
                } else {
                    Text(L("common.irreversible"))
                }
            }
            .alert(item: $archiveAction) { action in
                switch action {
                case .archiveTemplate(let template):
                    return Alert(
                        title: Text(L("archive.confirm_title")),
                        message: Text(String(format: L("archive.confirm_main"), template.name)),
                        primaryButton: .destructive(Text(L("action.archive"))) {
                            template.isArchived = true
                        },
                        secondaryButton: .cancel(Text(L("action.cancel")))
                    )
                case .archiveDaily(let item):
                    return Alert(
                        title: Text(L("archive.confirm_title")),
                        message: Text(String(format: L("archive.confirm_daily"), item.name)),
                        primaryButton: .destructive(Text(L("action.archive"))) {
                            item.isArchived = true
                        },
                        secondaryButton: .cancel(Text(L("action.cancel")))
                    )
                case .unarchiveTemplate(let template):
                    return Alert(
                        title: Text(L("archive.restore_title")),
                        message: Text(String(format: L("archive.restore_main"), template.name)),
                        primaryButton: .default(Text(L("action.unarchive"))) {
                            template.isArchived = false
                        },
                        secondaryButton: .cancel(Text(L("action.cancel")))
                    )
                case .unarchiveDaily(let item):
                    return Alert(
                        title: Text(L("archive.restore_title")),
                        message: Text(String(format: L("archive.restore_daily"), item.name)),
                        primaryButton: .default(Text(L("action.unarchive"))) {
                            item.isArchived = false
                        },
                        secondaryButton: .cancel(Text(L("action.cancel")))
                    )
                }
            }
        }
    }

    private func deleteTemplate(_ template: DungeonTemplate) {
        for effect in template.effects {
            modelContext.delete(effect)
        }
        for log in logs where log.template?.id == template.id {
            log.template = nil
        }
        modelContext.delete(template)
    }

    private func moveTemplates(from source: IndexSet, to destination: Int) {
        var updated = templates
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, item) in updated.enumerated() {
            item.sortIndex = index
        }
    }

    private func moveDailyLife(from source: IndexSet, to destination: Int) {
        var updated = dailyLifeItems
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, item) in updated.enumerated() {
            item.sortIndex = index
        }
    }

    private func normalizeTemplateOrder() {
        guard templates.count > 1 else { return }
        let allZero = templates.allSatisfy { $0.sortIndex == 0 }
        guard allZero else { return }
        let ordered = templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
    }

    private func normalizeDailyLifeOrder() {
        guard dailyLifeItems.count > 1 else { return }
        let allZero = dailyLifeItems.allSatisfy { $0.sortIndex == 0 }
        guard allZero else { return }
        let ordered = dailyLifeItems.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for (index, item) in ordered.enumerated() {
            item.sortIndex = index
        }
    }

}

private struct DungeonTemplateRow: View {
    let template: DungeonTemplate

    var body: some View {
        HStack {
            Text(template.name)
            Spacer()
            Text(template.usesDuration ? L("dungeon.uses_duration_short") : L("dungeon.fixed_short"))
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct DailyLifeRow: View {
    let item: DailyLifeItem

    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct DungeonsView_Previews: PreviewProvider {
    static var previewContainer: ModelContainer = {
        let container = try! ModelContainer(
            for: AttributeGroup.self,
                RPGAttribute.self,
                DailyLifeItem.self,
                DungeonTemplate.self,
                DungeonEffectTemplate.self,
                DungeonLog.self,
                DungeonEffectLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let group = AttributeGroup(name: "语言能力")
        let english = RPGAttribute(name: "英语", baseValue: 5, weight: 1, group: group)
        group.entries = [english]
        context.insert(group)
        context.insert(english)

        let template = DungeonTemplate(name: "读书", usesDuration: true)
        let effect = DungeonEffectTemplate(attribute: english, multiplier: 1, template: template)
        template.effects = [effect]
        context.insert(template)
        context.insert(effect)
        context.insert(DailyLifeItem(name: "上厕所"))

        return container
    }()

    static var previews: some View {
        DungeonsView()
            .modelContainer(previewContainer)
    }
}
