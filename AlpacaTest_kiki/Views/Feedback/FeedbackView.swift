//
//  FeedbackView.swift
//  AlpacaTest_kiki
//
//  Feedback main screen (FBK-01/02/06/07/08). Owned by B.
//

import SwiftUI
import SwiftData

struct FeedbackView: View {
    @Query(sort: \DailyStat.date) private var stats: [DailyStat]

    private var calendar: Calendar { Calendar.current }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    private var sixMonthsAgo: Date {
        calendar.date(byAdding: .month, value: -6, to: today) ?? today
    }

    private var currentWeekDates: [Date] {
        weekDates(startingAt: currentWeekStart)
    }

    private var todayStat: DailyStat? {
        stats.first { calendar.isDate($0.date, inSameDayAs: today) && !$0.isClosed }
            ?? stats.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var todayWool: Int {
        todayStat?.woolG ?? 0
    }

    private var historicalWeeks: [WeeklyFeedbackData] {
        let eligibleStats = stats.filter { stat in
            let day = calendar.startOfDay(for: stat.date)
            return day < currentWeekStart && day >= sixMonthsAgo
        }

        let starts = Set(eligibleStats.map { stat in
            calendar.dateInterval(of: .weekOfYear, for: stat.date)?.start ?? calendar.startOfDay(for: stat.date)
        })

        return starts
            .sorted(by: >)
            .map { start in
                WeeklyFeedbackData(
                    startDate: start,
                    dates: weekDates(startingAt: start),
                    stats: statsForWeek(startingAt: start)
                )
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    liveSummary
                    currentWeekSnapshots

                    if !historicalWeeks.isEmpty {
                        historicalWeeklyBlocks
                    }

                    historyBoundary
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("記錄與回饋")
        }
    }

    private var liveSummary: some View {
        VStack(spacing: 18) {
            AlpacaFeedbackSnapshot(woolG: todayWool, size: 148)

            VStack(spacing: 8) {
                Text("目前羊毛重量 \(todayWool) g")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(FeedbackCaptions.caption(for: todayWool))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 24)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private var currentWeekSnapshots: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本週快照")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 9) {
                ForEach(currentWeekDates, id: \.self) { date in
                    WeeklySnapshotCell(
                        date: date,
                        stat: stat(for: date),
                        relation: relation(to: date),
                        showsProgressText: true
                    )
                }
            }
        }
    }

    private var historicalWeeklyBlocks: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("歷史週次")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

            ForEach(historicalWeeks) { week in
                HistoricalWeeklyBlock(week: week)
            }
        }
    }

    private var historyBoundary: some View {
        Text("已顯示最近六個月資料")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 20)
    }

    private func weekDates(startingAt start: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func stat(for date: Date) -> DailyStat? {
        stats.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func statsForWeek(startingAt start: Date) -> [DailyStat] {
        let dates = weekDates(startingAt: start)
        return dates.compactMap { stat(for: $0) }
    }

    private func relation(to date: Date) -> WeekDateRelation {
        if calendar.isDate(date, inSameDayAs: today) {
            return .today
        }

        return date < today ? .past : .future
    }
}


private enum WeekDateRelation {
    case past
    case today
    case future
}

private struct WeeklyFeedbackData: Identifiable {
    let id = UUID()
    let startDate: Date
    let dates: [Date]
    let stats: [DailyStat]

    var endDate: Date {
        dates.last ?? startDate
    }

    var totalWool: Int {
        stats.reduce(0) { $0 + $1.woolG }
    }

    var doneCount: Int {
        stats.reduce(0) { $0 + $1.doneCount }
    }

    var stuckCount: Int {
        stats.reduce(0) { $0 + $1.stuckCount }
    }
}

private struct HistoricalWeeklyBlock: View {
    let week: WeeklyFeedbackData

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(weekRangeText)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text("\(week.totalWool) g")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surfaceMint.opacity(0.7), in: Capsule())
            }

            HStack(spacing: 9) {
                ForEach(week.dates, id: \.self) { date in
                    WeeklySnapshotCell(
                        date: date,
                        stat: stat(for: date),
                        relation: .past,
                        showsProgressText: false
                    )
                }
            }

            WeeklyFeedbackText(week: week)
        }
        .padding(18)
        .softFeedbackCard(surface: .white.opacity(0.58))
    }

    private var weekRangeText: String {
        let start = week.startDate.formatted(.dateTime.month(.abbreviated).day())
        let end = week.endDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) - \(end)"
    }

    private func stat(for date: Date) -> DailyStat? {
        week.stats.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

private struct WeeklyFeedbackText: View {
    let week: WeeklyFeedbackData

    private var hasEnoughData: Bool {
        week.stats.count >= 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            feedbackRow(title: "本週肯定", text: affirmationText, tint: Theme.surfaceLeaf)
            feedbackRow(title: "這週的卡關時刻", text: stuckText, tint: Theme.surfaceLavender)
            feedbackRow(title: "給這週的你", text: suggestionText, tint: Theme.surfaceMint)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Theme.background.opacity(0.9))
        )
    }

    private func feedbackRow(title: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                Text(text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.primaryText.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var affirmationText: String {
        if week.totalWool == 0 {
            return hasEnoughData ? "這週的紀錄很安靜，也許你把力氣留給了生活本身。" : "資料還不多，先把這週當成重新觀察自己的起點。"
        }

        return "你這週累積了 \(week.totalWool) g 羊毛，完成感不是突然出現，是被你每天慢慢堆起來的。"
    }

    private var stuckText: String {
        if week.stuckCount == 0 {
            return hasEnoughData ? "這週幾乎沒有留下卡關紀錄，看起來節奏相對順。" : "目前資料不足，還不能很確定卡關模式。"
        }

        return "你留下了 \(week.stuckCount) 次卡關求助，這代表你有在辨認阻力，而不是只是硬撐。"
    }

    private var suggestionText: String {
        if week.doneCount >= 3 {
            return "下週可以延續這個節奏，把大任務先拆小，再讓完成感更早出現。"
        }

        return "下週先挑一件最容易開始的事，把開始門檻降到小到不能再小。"
    }
}

private struct WeeklySnapshotCell: View {
    let date: Date
    let stat: DailyStat?
    let relation: WeekDateRelation
    var showsProgressText: Bool

    private var dayText: String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    private var dayNumber: String {
        date.formatted(.dateTime.day())
    }

    private var canOpenDailyFeedback: Bool {
        relation == .past && stat != nil
    }

    var body: some View {
        Group {
            if canOpenDailyFeedback {
                NavigationLink {
                    DailyFeedbackView(date: date)
                } label: {
                    cellContent(isInteractive: true)
                }
                .buttonStyle(.plain)
            } else if relation == .future {
                futureContent
            } else {
                cellContent(isInteractive: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cellContent(isInteractive: Bool) -> some View {
        VStack(spacing: 7) {
            Text(dayText)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.tertiaryText)

            Text(dayNumber)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            if let stat {
                AlpacaFeedbackSnapshot(woolG: stat.woolG, size: 36)
                Text(labelText(for: stat))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "pawprint")
                    .font(.title3)
                    .foregroundStyle(Theme.surfaceLavender.opacity(0.72))
                Text(relation == .today ? "進行中" : "無紀錄")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(minHeight: 112)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(cellSurface(isInteractive: isInteractive))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .stroke(relation == .today ? Theme.highlight.opacity(0.75) : .white.opacity(0.75), lineWidth: relation == .today ? 1.5 : 1)
        )
    }

    private var futureContent: some View {
        VStack(spacing: 9) {
            Text(dayText)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.tertiaryText.opacity(0.6))

            Text(dayNumber)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.tertiaryText.opacity(0.6))

            Text("?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText.opacity(0.5))
        }
        .frame(minHeight: 112)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(.white.opacity(0.38))
        )
    }

    private func cellSurface(isInteractive: Bool) -> Color {
        if relation == .today {
            return Theme.highlight.opacity(0.12)
        }

        return isInteractive ? .white.opacity(0.72) : .white.opacity(0.46)
    }

    private func labelText(for stat: DailyStat) -> String {
        if relation == .today {
            return "進行中"
        }

        return showsProgressText ? "\(stat.woolG)g" : "\(stat.doneCount) 完成"
    }
}

struct AlpacaFeedbackSnapshot: View {
    let woolG: Int
    var size: CGFloat

    private var tier: Int {
        switch woolG {
        case ..<200: return 0
        case ..<600: return 1
        case ..<1000: return 2
        default: return 3
        }
    }

    private var color: Color {
        switch tier {
        case 0: return Theme.surfaceMint
        case 1: return Theme.primary
        case 2: return Theme.surfaceLeaf
        default: return Theme.surfaceLavender
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))

            Circle()
                .fill(.white.opacity(0.34))
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(x: -size * 0.04, y: -size * 0.03)

            Image(systemName: tier >= 2 ? "pawprint.circle.fill" : "pawprint.circle")
                .resizable()
                .scaledToFit()
                .padding(size * 0.19)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: tier)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("羊駝蓬鬆程度")
    }
}

enum FeedbackCaptions {
    private static let lines = [
        "羊駝正在偷偷長出今天的成就感。",
        "這些毛線不是奇蹟，是你一點一點做出來的。",
        "今日能量已經有形狀了，摸起來應該很蓬。"
    ]

    static func caption(for woolG: Int) -> String {
        let bucket = max(woolG / 200, 0)
        return lines[bucket % lines.count]
    }
}

#Preview {
    FeedbackView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
