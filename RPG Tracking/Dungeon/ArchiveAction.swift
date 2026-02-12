//
//  ArchiveAction.swift
//  RPG Tracking
//

import Foundation

enum ArchiveAction: Identifiable {
    case archiveTemplate(DungeonTemplate)
    case archiveDaily(DailyLifeItem)
    case unarchiveTemplate(DungeonTemplate)
    case unarchiveDaily(DailyLifeItem)

    var id: String {
        switch self {
        case .archiveTemplate(let template):
            return "archive-template-\(template.id)"
        case .archiveDaily(let item):
            return "archive-daily-\(item.id)"
        case .unarchiveTemplate(let template):
            return "unarchive-template-\(template.id)"
        case .unarchiveDaily(let item):
            return "unarchive-daily-\(item.id)"
        }
    }
}
