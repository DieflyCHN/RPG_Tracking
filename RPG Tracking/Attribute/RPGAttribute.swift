//
//  RPGAttribute.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import Foundation
import SwiftData

enum AttributeKind: String, CaseIterable, Identifiable, Codable {
    case cumulative
    case decay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cumulative:
            return L("attribute.kind.cumulative")
        case .decay:
            return L("attribute.kind.decay")
        }
    }
}

@Model
final class AttributeGroup: Identifiable {
    var id: UUID
    var name: String
    var entries: [RPGAttribute] = []
    var sortIndex: Int

    init(name: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
    }

    func averageExperience(asOf date: Date = .now) -> Double {
        guard !entries.isEmpty else { return 0 }
        let weights = entries.map { max(0, $0.weight) }
        let totalWeight = weights.reduce(0, +)
        if totalWeight > 0 {
            let weightedSum = zip(entries, weights).reduce(0.0) { acc, pair in
                let (attr, weight) = pair
                return acc + attr.effectiveExperience(asOf: date) * weight
            }
            return weightedSum / totalWeight
        }

        let sum = entries.reduce(0.0) { $0 + $1.effectiveExperience(asOf: date) }
        return sum / Double(entries.count)
    }

    func level(asOf date: Date = .now) -> Int {
        Int(averageExperience(asOf: date) / 100) + 1
    }

    func progress(asOf date: Date = .now) -> Double {
        let exp = averageExperience(asOf: date)
        let remainder = exp.truncatingRemainder(dividingBy: 100)
        return remainder / 100
    }
}

@Model
final class RPGAttribute: Identifiable {
    var id: UUID
    var name: String
    var baseValue: Double
    var weight: Double
    var experience: Double
    var kindRaw: String
    var decayPerDay: Double
    var lastGainAt: Date?
    var sortIndex: Int

    var group: AttributeGroup?

    init(
        name: String,
        baseValue: Double = 0,
        weight: Double = 1,
        kind: AttributeKind = .cumulative,
        decayPerDay: Double = 0.05,
        group: AttributeGroup? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.baseValue = baseValue
        self.weight = weight
        self.experience = 0
        self.kindRaw = kind.rawValue
        self.decayPerDay = decayPerDay
        self.lastGainAt = nil
        self.group = group
        self.sortIndex = sortIndex
    }

    var kind: AttributeKind {
        get { AttributeKind(rawValue: kindRaw) ?? .cumulative }
        set { kindRaw = newValue.rawValue }
    }

    private func earnedExperience(asOf date: Date = .now) -> Double {
        guard kind == .decay else { return max(0, experience) }
        guard let lastGainAt else { return max(0, experience) }

        let secondsPerDay = 86_400.0
        let daysSinceGain = max(0, date.timeIntervalSince(lastGainAt) / secondsPerDay)
        guard daysSinceGain > 3 else { return max(0, experience) }

        let decayDays = floor(daysSinceGain - 3)
        let decayed = experience - (decayPerDay * decayDays)
        return max(0, decayed)
    }

    func effectiveExperience(asOf date: Date = .now) -> Double {
        let base = max(0, baseValue)
        return base + earnedExperience(asOf: date)
    }

    func level(asOf date: Date = .now) -> Int {
        Int(effectiveExperience(asOf: date) / 100) + 1
    }

    func progress(asOf date: Date = .now) -> Double {
        let exp = effectiveExperience(asOf: date)
        let remainder = exp.truncatingRemainder(dividingBy: 100)
        return remainder / 100
    }

    func applyGain(_ gain: Double, asOf date: Date = .now) {
        guard gain > 0 else { return }
        let base = earnedExperience(asOf: date)
        experience = base + gain
        lastGainAt = date
    }
}
