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

    @State private var showAddTemplate = false
    @State private var showAddLog = false
    @State private var selectedTemplate: DungeonTemplate?
    @State private var selectedLog: DungeonLog?
    @State private var pendingDeleteTemplate: DungeonTemplate?
    @State private var pendingDeleteLog: DungeonLog?
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
                                    pendingDeleteLog = nil
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("记录") {
                    if logs.isEmpty {
                        Text("暂无记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(logs) { log in
                            Button {
                                selectedLog = log
                            } label: {
                                DungeonLogRow(log: log)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDeleteLog = log
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
                        Button("记录支线副本") { showAddLog = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTemplate) {
                AddDungeonTemplateView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddLog) {
                AddDungeonLogView(template: nil)
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedTemplate) { template in
                AddDungeonLogView(template: template)
                    .presentationDetents([.large])
            }
            .sheet(item: $selectedLog) { log in
                EditDungeonLogView(log: log)
                    .presentationDetents([.large])
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    pendingDeleteTemplate = nil
                    pendingDeleteLog = nil
                }
                Button("删除", role: .destructive) {
                    if let template = pendingDeleteTemplate {
                        deleteTemplate(template)
                    } else if let log = pendingDeleteLog {
                        deleteLog(log)
                    }
                    pendingDeleteTemplate = nil
                    pendingDeleteLog = nil
                }
            } message: {
                if let template = pendingDeleteTemplate {
                    Text("将删除主线副本“\(template.name)”。此操作无法撤销。")
                } else if let log = pendingDeleteLog {
                    Text("将删除记录“\(log.name)”。此操作无法撤销。")
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

    private func deleteLog(_ log: DungeonLog) {
        var seen = Set<UUID>()
        var affected: [RPGAttribute] = []
        for effect in log.effects {
            guard let attr = effect.attribute else { continue }
            if seen.insert(attr.id).inserted {
                affected.append(attr)
            }
        }

        for effect in log.effects {
            modelContext.delete(effect)
        }
        modelContext.delete(log)

        AttributeRecalculator.recalculateAttributes(affected, in: modelContext)
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

private struct DungeonLogRow: View {
    let log: DungeonLog

    var body: some View {
        let totalEarned = log.effects.reduce(0.0) { $0 + $1.earned }
        let dateText = DateFormatters.fullDateTime.string(from: log.date)

        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.name)
                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "+%.2f", totalEarned))
                    .monospacedDigit()
                if log.isFailed {
                    Text("未达预期")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("评分 \(log.rating)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private enum DateFormatters {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter
    }()
}

struct DungeonsView_Previews: PreviewProvider {
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
        group.entries = [english]
        context.insert(group)
        context.insert(english)

        let template = DungeonTemplate(name: "读书", usesDuration: true)
        let effect = DungeonEffectTemplate(attribute: english, multiplier: 1, template: template)
        template.effects = [effect]
        context.insert(template)
        context.insert(effect)

        return container
    }()

    static var previews: some View {
        DungeonsView()
            .modelContainer(previewContainer)
    }
}
