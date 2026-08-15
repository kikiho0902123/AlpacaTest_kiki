//
//  FeedbackView.swift
//  AlpacaTest_kiki
//
//  Feedback main screen (FBK-01/02/06/07/08). Owned by B.
//  定位：History + Reflection + Feedback，不提供任務操作。
//

import SwiftUI
import SwiftData
import UIKit

struct FeedbackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStat.date) private var stats: [DailyStat]
    @Query(sort: \TodoTask.createdAt) private var tasks: [TodoTask]
    @Query(sort: \TaskLog.timestamp) private var logs: [TaskLog]

    @State private var liveAlpacaOffset: CGFloat = -4
    @State private var liveTodayWool: Int?
    @State private var liveAlpacaTier = 0

    private var calendar: Calendar { Calendar.current }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var currentWeekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    private let historyWeekCount = 12

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

    private var displayedTodayWool: Int {
        liveTodayWool ?? todayWool
    }

    private var displayedLiveAlpacaTier: Int {
        AlpacaFeedbackSnapshot.tier(forGrowthCount: liveAlpacaTier)
    }

    // 歷史週次：固定顯示最近 12 週，不包含本週；越新的週越上方。
    private var historicalWeeks: [WeeklyFeedbackData] {
        (1...historyWeekCount).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else {
                return nil
            }

            let dates = weekDates(startingAt: start)
            return WeeklyFeedbackData(
                startDate: start,
                dates: dates,
                stats: statsForWeek(dates),
                tasks: tasksForWeek(dates),
                logs: logsForWeek(dates)
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // UI 區塊 1：當下羊駝狀態。代表今天的 live state，不是歷史快照。
                    liveSummary

                    // UI 區塊 2：本週七天 timeline。只有已結束、已存檔的日期可以點進日回饋。
                    currentWeekSnapshots

                    // UI 區塊 3：歷史週次。每週包含日期範圍、七天快照與週回饋文字。
                    if !historicalWeeks.isEmpty {
                        historicalWeeklyBlocks
                    }

                    // UI 區塊 4：三個月歷史資料保存邊界。
                    historyBoundary
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("記錄與回饋")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            refreshLiveTodayWool()
        }
        // 整包重新取，不要只更新羊毛數。收割後會換一筆新的工作日（woolG 歸 0），
        // 羊駝的階段也要跟著重新讀，否則畫面會停在收割前的滿階。
        .onChange(of: todayWool) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                refreshLiveTodayWool()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .woolGained)) { notification in
            if let totalToday = notification.userInfo?["totalToday"] as? Int {
                withAnimation(.easeInOut(duration: 0.25)) {
                    liveTodayWool = totalToday
                    if let growthTier = notification.userInfo?["growthTier"] as? Int {
                        liveAlpacaTier = growthTier
                    } else {
                        liveAlpacaTier = min(liveAlpacaTier + 1, 3)
                    }
                }
            } else {
                refreshLiveTodayWool()
            }
        }
    }

    private var liveSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 18) {
                // 這裡用輕微 idle animation 表示「正在進行中的一天」。
                AlpacaFeedbackSnapshot(woolG: displayedTodayWool, size: 150, isLive: true, growthTier: displayedLiveAlpacaTier)
                    .offset(y: liveAlpacaOffset)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: liveAlpacaOffset)
                    .onAppear { liveAlpacaOffset = 4 }

                VStack(spacing: 8) {
                    // 回饋頁可以顯示今日累積羊毛；今日任務頁才維持不顯示克數。
                    Text("目前已累積 \(displayedTodayWool) 克羊毛")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(FeedbackCaptions.caption(for: displayedTodayWool))
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private var currentWeekSnapshots: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(historicalWeeks) { week in
                HistoricalWeeklyBlock(week: week)
            }
        }
    }

    private var historyBoundary: some View {
        Text("已顯示最近三個月，共 12 週資料")
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

    private func statsForWeek(_ dates: [Date]) -> [DailyStat] {
        dates.compactMap { stat(for: $0) }
    }

    private func tasksForWeek(_ dates: [Date]) -> [TodoTask] {
        tasks.filter { task in
            dates.contains { date in
                calendar.isDate(task.createdAt, inSameDayAs: date)
                    || task.startDate.map { calendar.isDate($0, inSameDayAs: date) } == true
            }
        }
    }

    private func logsForWeek(_ dates: [Date]) -> [TaskLog] {
        logs.filter { log in
            dates.contains { calendar.isDate(log.timestamp, inSameDayAs: $0) }
        }
    }

    private func relation(to date: Date) -> WeekDateRelation {
        if calendar.isDate(date, inSameDayAs: today) {
            return .today
        }

        return date < today ? .past : .future
    }

    private func refreshLiveTodayWool() {
        let descriptor = FetchDescriptor<DailyStat>(sortBy: [SortDescriptor(\DailyStat.date)])
        let allStats = (try? modelContext.fetch(descriptor)) ?? []
        let openTodayStat = allStats.first { calendar.isDate($0.date, inSameDayAs: today) && !$0.isClosed }
        let anyTodayStat = allStats.first { calendar.isDate($0.date, inSameDayAs: today) }
        liveTodayWool = (openTodayStat ?? anyTodayStat)?.woolG ?? 0
        liveAlpacaTier = RewardEngine.alpacaGrowthTier(for: today)
    }
}

private enum WeekDateRelation {
    case past
    case today
    case future
}

private struct WeeklyFeedbackData: Identifiable {
    let startDate: Date
    let dates: [Date]
    let stats: [DailyStat]
    let tasks: [TodoTask]
    let logs: [TaskLog]

    // 同一週在畫面重算後仍要是同一個項目，否則 SwiftUI 會重建整個區塊並重跑 `.task`。
    var id: Date { startDate }

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

    var completionLogs: [TaskLog] {
        logs.filter { $0.type == "completion" }
    }

    var stuckLogs: [TaskLog] {
        logs.filter { $0.type == "chatSummary" }
    }
}

private struct HistoricalWeeklyBlock: View {
    let week: WeeklyFeedbackData

    @State private var feedbackText: String?
    @State private var isLoadingFeedback = true

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(Theme.surfaceMint.opacity(0.65))

            // 週 Header：讓使用者滑很深時仍知道自己看到哪一週。
            HStack(alignment: .firstTextBaseline) {
                Text(weekRangeText)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text("\(week.totalWool) g")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            // 歷史週的七張快照：作為 Daily Feedback 的入口。
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

            // 週回饋：空白週由 API 回 nil，維持 placeholder；有資料才顯示三段式 AI 回饋。
            if let feedbackText {
                WeeklyFeedbackCard(text: feedbackText)
            } else if isLoadingFeedback {
                WeeklyFeedbackLoadingPlaceholder()
            } else {
                WeeklyFeedbackPlaceholder()
            }
        }
        .padding(.vertical, 18)
        .task(id: week.startDate) {
            isLoadingFeedback = true
            defer { isLoadingFeedback = false }
            feedbackText = try? await AIService.shared.weeklyFeedback(
                WeeklyStats(
                    startDate: week.startDate,
                    endDate: week.endDate,
                    stats: week.stats,
                    logs: week.logs,
                    tasks: week.tasks
                )
            )
        }
    }

    private var weekRangeText: String {
        let start = week.startDate.formatted(.dateTime.month().day())
        let end = week.endDate.formatted(.dateTime.month().day())
        return "\(start) - \(end)"
    }

    private func stat(for date: Date) -> DailyStat? {
        week.stats.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

private struct WeeklyFeedbackLoadingPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("正在整理這週的回饋…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Theme.background.opacity(0.9))
        )
    }
}

private struct WeeklyFeedbackCard: View {
    let text: String

    var body: some View {
        MarkdownText(raw: text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                    .fill(Theme.background.opacity(0.9))
            )
    }
}

private struct WeeklyFeedbackPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("週回饋文字")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)

            Text("這週還沒有足夠的活動資料可以產生回饋。")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Theme.background.opacity(0.9))
        )
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

    // 所有過去日期都是日回饋入口；沒有資料時由 DailyFeedbackView 顯示「當日無資料」。
    private var canOpenDailyFeedback: Bool {
        relation == .past
    }

    var body: some View {
        Group {
            if canOpenDailyFeedback {
                NavigationLink {
                    DailyFeedbackView(date: date)
                } label: {
                    pastContent
                }
                .buttonStyle(.plain)
            } else {
                dateOnlyContent(isCurrentDay: relation == .today)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pastContent: some View {
        Group {
            if let stat {
                pastContentWithSnapshot(stat)
            } else {
                dateOnlyContent(isCurrentDay: false)
            }
        }
    }

    private func pastContentWithSnapshot(_ stat: DailyStat) -> some View {
        VStack(spacing: 4) {
            Text(dayText)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.tertiaryText)

            Text(dayNumber)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            AlpacaFeedbackSnapshot(
                woolG: stat.woolG,
                size: 30,
                growthTier: AlpacaFeedbackSnapshot.tierForRecordedActions(
                    startCount: stat.startCount,
                    stuckCount: stat.stuckCount,
                    doneCount: stat.doneCount
                )
            )
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
    }

    private func dateOnlyContent(isCurrentDay: Bool) -> some View {
        VStack(spacing: 5) {
            Text(dayText)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(isCurrentDay ? Theme.tertiaryText : Theme.tertiaryText.opacity(0.65))

            Text(dayNumber)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isCurrentDay ? Theme.primaryText : Theme.tertiaryText.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(isCurrentDay ? Theme.highlight.opacity(0.12) : .white.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .stroke(isCurrentDay ? Theme.highlight.opacity(0.75) : .white.opacity(0.75), lineWidth: isCurrentDay ? 1.5 : 1)
        )
    }

}

/// 共用羊駝顯示元件：羊駝切圖規則集中在 B 的 FeedbackView。
struct AlpacaFeedbackSnapshot: View {
    let woolG: Int
    var size: CGFloat
    var isLive: Bool = false
    var growthTier: Int? = nil

    private static let assetNames = ["alpaca_0", "alpaca_1", "alpaca_2", "alpaca_3"]

    /// 羊駝圖片只看「成長次數」，不看目前幾克羊毛；成長三次後固定在最多毛的圖。
    static func tier(forGrowthCount growthCount: Int) -> Int {
        min(max(growthCount, 0), assetNames.count - 1)
    }

    /// 歷史快照沒有逐次事件資料時，用當天已記錄的主要行為次數作為快照階段。
    static func tierForRecordedActions(startCount: Int, stuckCount: Int, doneCount: Int) -> Int {
        tier(forGrowthCount: startCount + stuckCount + doneCount)
    }

    /// 給其他頁面需要直接取圖名時使用，避免各頁各自硬寫 alpaca_0...3。
    static func assetName(forTier tier: Int) -> String {
        let safeTier = Self.tier(forGrowthCount: tier)
        return assetNames[safeTier]
    }

    private var tier: Int {
        if let growthTier {
            return Self.tier(forGrowthCount: growthTier)
        }

        return Self.tier(forGrowthCount: woolG > 0 ? 1 : 0)
    }

    private var assetName: String {
        Self.assetName(forTier: tier)
    }

    private var fallbackColor: Color {
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
                .fill(fallbackColor.opacity(isLive ? 0.30 : 0.24))

            alpacaImage
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isLive ? "目前進行中的羊駝狀態" : "歷史羊駝快照")
    }

    @ViewBuilder
    private var alpacaImage: some View {
        if let image = UIImage(named: assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(size * 0.08)
                .symbolEffect(.bounce, value: tier)
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(systemName: tier >= 2 ? "pawprint.circle.fill" : "pawprint.circle")
            .resizable()
            .scaledToFit()
            .padding(size * 0.19)
            .foregroundStyle(fallbackColor)
            .symbolEffect(.bounce, value: tier)
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
