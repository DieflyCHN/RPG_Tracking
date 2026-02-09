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
    @Query(sort: \DungeonTemplate.name) private var templates: [DungeonTemplate]
    @Query(sort: \DungeonLog.date, order: .reverse) private var logs: [DungeonLog]
    @Query(sort: \DailyLifeItem.name) private var dailyLifeItems: [DailyLifeItem]

    @State private var showAddTemplate = false
    @State private var showAddDailyLife = false
    @State private var selectedTemplate: DungeonTemplate?
    @State private var selectedDailyLife: DailyLifeItem?
    @State private var pendingDeleteTemplate: DungeonTemplate?
    @State private var pendingDeleteDailyLife: DailyLifeItem?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("主线副本") {
                    if templates.isEmpty {
                        Text("暂无主线副本")
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
                                Button(role: .destructive) {
                                    pendingDeleteTemplate = template
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("日常生活") {
                    if dailyLifeItems.isEmpty {
                        Text("暂无内容")
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
                            Button(role: .destructive) {
                                pendingDeleteDailyLife = item
                                pendingDeleteTemplate = nil
                                showDeleteConfirm = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("副本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("添加主线副本") { showAddTemplate = true }
                        Button("添加日常生活") { showAddDailyLife = true }
                    } label: {
                        Image(systemName: "plus")
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
            .sheet(item: $selectedTemplate) { template in
                EditDungeonTemplateView(template: template)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedDailyLife) { item in
                EditDailyLifeView(item: item)
                    .presentationDetents([.medium])
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    pendingDeleteTemplate = nil
                    pendingDeleteDailyLife = nil
                }
                Button("删除", role: .destructive) {
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
                    Text("将删除主线副本“\(template.name)”。此操作无法撤销。")
                } else if let item = pendingDeleteDailyLife {
                    Text("将删除“\(item.name)”。此操作无法撤销。")
                } else {
                    Text("此操作无法撤销。")
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

}

private struct DungeonTemplateRow: View {
    let template: DungeonTemplate

    var body: some View {
        HStack {
            Text(template.name)
            Spacer()
            Text(template.usesDuration ? "按时间" : "固定")
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
