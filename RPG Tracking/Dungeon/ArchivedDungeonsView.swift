//
//  ArchivedDungeonsView.swift
//  RPG Tracking
//

import SwiftUI
import SwiftData

struct ArchivedDungeonsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<DungeonTemplate> { $0.isArchived }, sort: \DungeonTemplate.sortIndex) private var templates: [DungeonTemplate]
    @Query(filter: #Predicate<DailyLifeItem> { $0.isArchived }, sort: \DailyLifeItem.sortIndex) private var dailyLifeItems: [DailyLifeItem]
    @State private var expandMain = true
    @State private var expandDaily = true
    @State private var archiveAction: ArchiveAction?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DisclosureGroup(isExpanded: $expandMain) {
                        if templates.isEmpty {
                            Text(L("archive.empty_main"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(templates) { template in
                                DungeonTemplateRow(template: template)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            archiveAction = .unarchiveTemplate(template)
                                        } label: {
                                            Label(L("action.unarchive"), systemImage: "arrow.uturn.backward")
                                        }
                                    }
                            }
                        }
                    } label: {
                        Text(L("dungeon.main_section"))
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $expandDaily) {
                        if dailyLifeItems.isEmpty {
                            Text(L("archive.empty_daily"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dailyLifeItems) { item in
                                DailyLifeRow(item: item)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            archiveAction = .unarchiveDaily(item)
                                        } label: {
                                            Label(L("action.unarchive"), systemImage: "arrow.uturn.backward")
                                        }
                                    }
                            }
                        }
                    } label: {
                        Text(L("daily.section"))
                    }
                }
            }
            .navigationTitle(L("archive.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.close")) { dismiss() }
                }
            }
            .onAppear {
                normalizeTemplateOrder()
                normalizeDailyLifeOrder()
            }
            .alert(item: $archiveAction) { action in
                switch action {
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
                default:
                    return Alert(title: Text(L("archive.restore_title")))
                }
            }
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

struct ArchivedDungeonsView_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedDungeonsView()
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
