//
//  StatsView.swift
//  RPG Tracking
//
//  Created by Kornelius Schneider on 21.12.25.
//

import SwiftUI
import SwiftData

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case day
    case week
    case year
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .year: return "年"
        case .all: return "全部"
        }
    }
}

struct StatsView: View {
    @Query private var effects: [DungeonEffectLog]
    @Query(sort: \DungeonLog.date, order: .reverse) private var logs: [DungeonLog]
    @Environment(\.modelContext) private var modelContext
    @State private var range: StatsTimeRange = .week
    @AppStorage("statsHeatmapLatest") private var statsHeatmapLatest: Bool = true
    @AppStorage("statsCompactLogs") private var statsCompactLogs: Bool = false
    @State private var anchorDate: Date = Date()
    @State private var selectedLog: DungeonLog?
    @State private var pendingDeleteLog: DungeonLog?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HeatmapView(
                        data: heatmapAllData,
                        latestOnRight: statsHeatmapLatest,
                        highlightRange: range,
                        highlightAnchor: anchorDate
                    )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section {
                    TimeRangeRow(
                        range: range,
                        anchorDate: anchorDate,
                        onPrevious: { shiftAnchor(by: -1) },
                        onNext: { shiftAnchor(by: 1) }
                    )
                }

                Section("记录") {
                    HStack {
                        Text("总获取经验")
                        Spacer()
                        Text(String(format: "+%.2f", totalEarnedInRange))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)

                    if logsInRange.isEmpty {
                        Text("暂无记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(logsInRange) { log in
                            StatsLogRow(log: log, compact: statsCompactLogs)
                                .statsRowInsets(compact: statsCompactLogs)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        selectedLog = log
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        pendingDeleteLog = log
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .sheet(item: $selectedLog) { log in
                ModifyDungeonLogView(log: log)
                    .presentationDetents([.large])
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    pendingDeleteLog = nil
                }
                Button("删除", role: .destructive) {
                    if let log = pendingDeleteLog {
                        deleteLog(log)
                    }
                    pendingDeleteLog = nil
                }
            } message: {
                if let log = pendingDeleteLog {
                    Text("将删除记录“\(log.name)”。此操作无法撤销。")
                } else {
                    Text("此操作无法撤销。")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("时间范围") {
                            ForEach(StatsTimeRange.allCases) { option in
                                Button {
                                    range = option
                                } label: {
                                    if option == range {
                                        Label(option.label, systemImage: "checkmark")
                                    } else {
                                        Text(option.label)
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("范围")
                    }
                }
            }
            .onChange(of: range) { _, _ in
                anchorDate = Date()
            }
        }
    }

    private var heatmapAllData: [HeatmapDay] {
        HeatmapBuilder.build(
            effects: effects,
            range: .all,
            calendar: Calendar.current
        )
    }

    private var logsInRange: [DungeonLog] {
        let calendar = Calendar.current
        let interval = rangeInterval(range: range, anchor: anchorDate, calendar: calendar)
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)

        return logs.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= start && day <= end
        }
    }

    private var totalEarnedInRange: Double {
        logsInRange.reduce(0) { total, log in
            total + log.effects.reduce(0) { $0 + $1.earned }
        }
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

private struct TimeRangeRow: View {
    let range: StatsTimeRange
    let anchorDate: Date
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            if range != .all {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer()

            Text(displayText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            if range != .all {
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    private var displayText: String {
        let calendar = Calendar.current
        switch range {
        case .day:
            return "\(formatMonthDay(anchorDate))"
        case .week:
            let weekNumber = calendar.component(.weekOfYear, from: anchorDate)
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate)
            let start = interval?.start ?? anchorDate
            let end = (interval?.end ?? anchorDate).addingTimeInterval(-86_400)
            let weekText = String(format: "%02d", weekNumber)
            return "第\(weekText)周（\(formatMonthDay(start))-\(formatMonthDay(end))）"
        case .year:
            let year = calendar.component(.year, from: anchorDate)
            return "\(year)年"
        case .all:
            return "全部"
        }
    }

    private func formatMonthDay(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let monthText = String(format: "%02d", month)
        let dayText = String(format: "%02d", day)
        return "\(monthText)月\(dayText)日"
    }
}

private extension StatsView {
    func shiftAnchor(by step: Int) {
        let calendar = Calendar.current
        switch range {
        case .day:
            anchorDate = calendar.date(byAdding: .day, value: step, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = calendar.date(byAdding: .weekOfYear, value: step, to: anchorDate) ?? anchorDate
        case .year:
            anchorDate = calendar.date(byAdding: .year, value: step, to: anchorDate) ?? anchorDate
        case .all:
            break
        }
    }

    func rangeInterval(range: StatsTimeRange, anchor: Date, calendar: Calendar) -> DateInterval {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return DateInterval(start: start, end: start)
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            let start = calendar.startOfDay(for: interval?.start ?? anchor)
            let end = calendar.startOfDay(
                for: (interval?.end ?? anchor).addingTimeInterval(-86_400)
            )
            return DateInterval(start: start, end: end)
        case .year:
            let interval = calendar.dateInterval(of: .year, for: anchor)
            let start = calendar.startOfDay(for: interval?.start ?? anchor)
            let end = calendar.startOfDay(
                for: (interval?.end ?? anchor).addingTimeInterval(-86_400)
            )
            return DateInterval(start: start, end: end)
        case .all:
            let today = calendar.startOfDay(for: Date())
            let earliest = logs.map(\.date).min() ?? today
            let start = calendar.startOfDay(for: earliest)
            return DateInterval(start: start, end: today)
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}

private struct StatsLogRow: View {
    let log: DungeonLog
    let compact: Bool

    var body: some View {
        let totalEarned = log.effects.reduce(0.0) { $0 + $1.earned }
        let durationText = formatDuration(minutes: log.durationMinutes)

        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                Text(log.name)
                Text(durationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
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
        .font(.body)
        .padding(.vertical, compact ? 0 : 1)
    }

    private func formatDuration(minutes: Int) -> String {
        let totalMinutes = max(0, minutes)
        let totalHours = Double(totalMinutes) / 60.0
        if totalHours >= 24 {
            let days = totalHours / 24.0
            return String(format: "%.1f日", days)
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return String(format: "%02d小时%02d分钟", hours, mins)
    }
}

private extension View {
    @ViewBuilder
    func statsRowInsets(compact: Bool) -> some View {
        if compact {
            listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            self
        }
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

private struct HeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private enum HeatmapBuilder {
    static func build(effects: [DungeonEffectLog], range: StatsTimeRange, calendar: Calendar) -> [HeatmapDay] {
        let today = calendar.startOfDay(for: Date())

        let start: Date
        switch range {
        case .day:
            start = today
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .year:
            start = calendar.date(byAdding: .day, value: -364, to: today) ?? today
        case .all:
            let earliest = effects.compactMap { $0.log?.date }.min() ?? today
            start = calendar.startOfDay(for: earliest)
        }

        var dailyTotals: [Date: Double] = [:]
        for effect in effects {
            guard let date = effect.log?.date else { continue }
            let day = calendar.startOfDay(for: date)
            guard day >= start && day <= today else { continue }
            dailyTotals[day, default: 0] += effect.earned
        }

        var days: [HeatmapDay] = []
        var cursor = start
        while cursor <= today {
            let value = dailyTotals[cursor, default: 0]
            days.append(HeatmapDay(date: cursor, value: value))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }

        return days
    }
}

private struct HeatmapView: View {
    let data: [HeatmapDay]
    let latestOnRight: Bool
    let highlightRange: StatsTimeRange
    let highlightAnchor: Date

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 4
    private let highlightColor = Color.orange.opacity(0.22)
    var body: some View {
        let calendar: Calendar = {
            var calendar = Calendar.current
            calendar.firstWeekday = 2
            return calendar
        }()
        let today = calendar.startOfDay(for: Date())
        let grouped = groupByWeek(data: data, calendar: calendar, latestOnRight: latestOnRight)
        let maxValue = data.map(\.value).max() ?? 0
        let weekdayLabels = ["一", " ", "三", " ", "五", " ", "日"]
        let labelWidth: CGFloat = 26

        GeometryReader { proxy in
            let available = proxy.size.width
            let minColumns = max(Int(floor((available + cellSpacing) / (cellSize + cellSpacing))), 1)
            let columns = max(grouped.count, minColumns)
            let contentWidth = CGFloat(columns) * (cellSize + cellSpacing) - cellSpacing
            let padded = padWeeks(grouped, to: columns, latestOnRight: latestOnRight)
            let highlights = highlightSegments(
                weeks: padded,
                calendar: calendar,
                range: highlightRange,
                anchor: highlightAnchor
            )
            let monthLabels = monthLabelColumns(weeks: padded, calendar: calendar, latestOnRight: latestOnRight)
            let isScrollable = contentWidth > available + 1

            HStack(alignment: .top, spacing: 8) {
                if !latestOnRight {
                    weekdayColumn(labels: weekdayLabels, width: labelWidth)
                }

                HeatmapScrollView(latestOnRight: latestOnRight, isScrollable: isScrollable) {
                    VStack(alignment: .leading, spacing: 2) {
                        ZStack(alignment: .leading) {
                            ForEach(monthLabels.indices, id: \.self) { index in
                                if let label = monthLabels[index] {
                                    Text(label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: cellSize * 2 + cellSpacing, alignment: .leading)
                                        .offset(x: CGFloat(index) * (cellSize + cellSpacing))
                                }
                            }
                        }
                        .frame(width: contentWidth, height: 12, alignment: .leading)

                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(padded.indices, id: \.self) { index in
                                ZStack(alignment: .top) {
                                    VStack(spacing: cellSpacing) {
                                        ForEach(padded[index]) { day in
                                            let isFuture = calendar.startOfDay(for: day.date) > today
                                            let isPlaceholder = day.date == Date.distantPast
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(isFuture || isPlaceholder ? Color.clear : color(for: day.value, max: maxValue))
                                                .opacity(isFuture || isPlaceholder ? 0 : 1)
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }

                                    VStack(spacing: 0) {
                                        ForEach(highlights[index], id: \.self) { segment in
                                            let height = segmentHeight(segment)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(highlightColor)
                                                .frame(width: cellSize, height: height)
                                                .offset(y: segmentOffset(segment))
                                        }
                                    }
                                }
                                .id(index)
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.bottom, 6)
                    }
                    .frame(
                        width: max(contentWidth, available),
                        alignment: latestOnRight ? .trailing : .leading
                    )
                }

                if latestOnRight {
                    weekdayColumn(labels: weekdayLabels, width: labelWidth)
                }
            }
        }
        .frame(height: cellSize * 7 + cellSpacing * 6 + 18)
    }

    private struct HighlightSegment: Hashable {
        let startIndex: Int
        let endIndex: Int
    }

    private func groupByWeek(data: [HeatmapDay], calendar: Calendar, latestOnRight: Bool) -> [[HeatmapDay]] {
        guard !data.isEmpty else { return [] }

        var grouped: [Date: [HeatmapDay]] = [:]
        for day in data {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: day.date)?.start ?? day.date
            grouped[weekStart, default: []].append(day)
        }

        let sortedWeeks = grouped.keys.sorted()
        var buckets: [[HeatmapDay]] = []

        for weekStart in sortedWeeks {
            var week = (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                return HeatmapDay(date: date, value: 0)
            }
            for day in grouped[weekStart] ?? [] {
                let weekday = calendar.component(.weekday, from: day.date)
                let index = (weekday - calendar.firstWeekday + 7) % 7
                if index >= 0 && index < 7 {
                    week[index] = day
                }
            }
            buckets.append(week)
        }

        return latestOnRight ? buckets : buckets.reversed()
    }

    private func padWeeks(_ weeks: [[HeatmapDay]], to count: Int, latestOnRight: Bool) -> [[HeatmapDay]] {
        guard weeks.count < count else { return weeks }
        var padded = weeks
        let emptyWeek = (0..<7).map { _ in HeatmapDay(date: Date.distantPast, value: 0) }
        while padded.count < count {
            if latestOnRight {
                padded.insert(emptyWeek, at: 0)
            } else {
                padded.append(emptyWeek)
            }
        }
        return padded
    }

    private func highlightSegments(
        weeks: [[HeatmapDay]],
        calendar: Calendar,
        range: StatsTimeRange,
        anchor: Date
    ) -> [[HighlightSegment]] {
        guard range != .all else {
            return Array(repeating: [], count: weeks.count)
        }

        let interval = rangeInterval(range: range, anchor: anchor, calendar: calendar)
        let start = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let today = calendar.startOfDay(for: Date())

        var result: [[HighlightSegment]] = []

        for week in weeks {
            var indices: [Int] = []
            for (idx, day) in week.enumerated() {
                guard day.date != Date.distantPast else { continue }
                let dayStart = calendar.startOfDay(for: day.date)
                guard dayStart <= today else { continue }
                if dayStart >= start && dayStart <= end {
                    indices.append(idx)
                }
            }

            result.append(buildSegments(from: indices))
        }

        return result
    }

    private func rangeInterval(range: StatsTimeRange, anchor: Date, calendar: Calendar) -> DateInterval {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return DateInterval(start: start, end: start)
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
            let start = calendar.startOfDay(for: interval?.start ?? anchor)
            let end = calendar.startOfDay(
                for: (interval?.end ?? anchor).addingTimeInterval(-86_400)
            )
            return DateInterval(start: start, end: end)
        case .year:
            let interval = calendar.dateInterval(of: .year, for: anchor)
            let start = calendar.startOfDay(for: interval?.start ?? anchor)
            let end = calendar.startOfDay(
                for: (interval?.end ?? anchor).addingTimeInterval(-86_400)
            )
            return DateInterval(start: start, end: end)
        case .all:
            return DateInterval(start: anchor, end: anchor)
        }
    }

    private func buildSegments(from indices: [Int]) -> [HighlightSegment] {
        guard !indices.isEmpty else { return [] }
        let sorted = indices.sorted()
        var segments: [HighlightSegment] = []
        var start = sorted[0]
        var prev = sorted[0]

        for idx in sorted.dropFirst() {
            if idx == prev + 1 {
                prev = idx
            } else {
                segments.append(HighlightSegment(startIndex: start, endIndex: prev))
                start = idx
                prev = idx
            }
        }
        segments.append(HighlightSegment(startIndex: start, endIndex: prev))
        return segments
    }

    private func segmentOffset(_ segment: HighlightSegment) -> CGFloat {
        let start = CGFloat(segment.startIndex)
        return start * (cellSize + cellSpacing)
    }

    private func segmentHeight(_ segment: HighlightSegment) -> CGFloat {
        let count = CGFloat(segment.endIndex - segment.startIndex + 1)
        return count * cellSize + (count - 1) * cellSpacing
    }

    private func color(for value: Double, max: Double) -> Color {
        guard value > 0, max > 0 else { return Color(.systemGray5) }
        let ratio = value / max
        switch ratio {
        case 0..<0.25: return Color(red: 0.75, green: 0.90, blue: 0.75)
        case 0.25..<0.5: return Color(red: 0.45, green: 0.80, blue: 0.45)
        case 0.5..<0.75: return Color(red: 0.20, green: 0.65, blue: 0.25)
        default: return Color(red: 0.10, green: 0.50, blue: 0.15)
        }
    }

    @ViewBuilder
    private func weekdayColumn(labels: [String], width: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(labels.indices, id: \.self) { index in
                let label = labels[index]
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: width, height: cellSize, alignment: .center)
                    .opacity(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
            }
        }
        .padding(.top, 12)
    }

    private func monthLabelColumns(
        weeks: [[HeatmapDay]],
        calendar: Calendar,
        latestOnRight: Bool
    ) -> [String?] {
        var labels = Array<String?>(repeating: nil, count: weeks.count)
        var previousMonth: Int?

        let indices = latestOnRight ? Array(weeks.indices) : Array(weeks.indices.reversed())

        for index in indices {
            let week = weeks[index]
            let day = week.first { $0.date != Date.distantPast }
            guard let day else { continue }
            let month = calendar.component(.month, from: day.date)
            if previousMonth != month {
                labels[index] = String(format: "%02d", month)
                previousMonth = month
            }
        }

        return labels
    }
}

private struct HeatmapScrollView<Content: View>: UIViewRepresentable {
    let latestOnRight: Bool
    let isScrollable: Bool
    let content: Content

    init(latestOnRight: Bool, isScrollable: Bool, @ViewBuilder content: () -> Content) {
        self.latestOnRight = latestOnRight
        self.isScrollable = isScrollable
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .clear

        let host = UIHostingController(rootView: content)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        scrollView.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.host = host
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.host?.rootView = content
        uiView.isScrollEnabled = isScrollable
        uiView.alwaysBounceHorizontal = isScrollable
        uiView.layoutIfNeeded()

        let maxOffset = max(0, uiView.contentSize.width - uiView.bounds.width)
        let targetX = latestOnRight ? maxOffset : 0
        if abs(uiView.contentOffset.x - targetX) > 1 {
            uiView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var host: UIHostingController<Content>?
    }
}
