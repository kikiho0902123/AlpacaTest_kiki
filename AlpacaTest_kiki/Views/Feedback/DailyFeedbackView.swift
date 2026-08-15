//
//  DailyFeedbackView.swift
//  AlpacaTest_kiki
//
//  Daily feedback detail (FBK-03/04/05/09 entry). Owned by B.
//  定位：已結束工作日的歷史閱讀頁，不提供任務操作。
//

import SwiftUI
import SwiftData

struct DailyFeedbackView: View {
    let date: Date

    @Query(sort: \DailyStat.date) private var stats: [DailyStat]
    @Query(sort: \TodoTask.createdAt) private var tasks: [TodoTask]
    @Query(sort: \TaskLog.timestamp) private var logs: [TaskLog]

    private var calendar: Calendar { Calendar.current }

    private var dayStat: DailyStat? {
        stats.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var dayLogs: [TaskLog] {
        logs.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    // 目前模型尚未有 snapshot table，因此先用建立日、排程日與 TaskLog 推回該日任務集合。
    private var dayTasks: [TodoTask] {
        let loggedTaskIDs = Set(dayLogs.map(\.taskID))
        return tasks.filter { task in
            loggedTaskIDs.contains(task.id)
                || calendar.isDate(task.createdAt, inSameDayAs: date)
                || task.startDate.map { calendar.isDate($0, inSameDayAs: date) } == true
        }
    }

    private var groupedTasks: [DailyTaskGroup] {
        DailyTaskGroup.grouped(tasks: dayTasks)
    }

    private var woolG: Int {
        dayStat?.woolG ?? 0
    }

    private var snapshotTier: Int {
        guard let dayStat else { return 0 }
        return AlpacaFeedbackSnapshot.tierForRecordedActions(
            startCount: dayStat.startCount,
            stuckCount: dayStat.stuckCount,
            doneCount: dayStat.doneCount
        )
    }

    private var hasAnyDayData: Bool {
        dayStat != nil || !dayTasks.isEmpty || !dayLogs.isEmpty
    }

    private var shareText: String {
        if hasAnyDayData {
            return "\(date.formatted(.dateTime.month().day().weekday(.wide))) 累積 \(woolG) g 羊毛，完成 \(dayStat?.doneCount ?? 0) 件任務。"
        }

        return "\(date.formatted(.dateTime.month().day().weekday(.wide))) 當日無資料。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // UI 區塊 1：日回饋 Header，呈現該日最終羊駝快照與羊毛成果。
                daySummary

                // UI 區塊 2：歷史任務列表，依固定順序分組顯示；無資料日不顯示下半部。
                if hasAnyDayData {
                    taskSection
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("日回饋")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var daySummary: some View {
        VStack(spacing: 18) {
            Text(date.formatted(.dateTime.year().month(.wide).day().weekday(.wide)))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            AlpacaFeedbackSnapshot(woolG: woolG, size: 136, growthTier: snapshotTier)

            VStack(spacing: 8) {
                Text(hasAnyDayData ? "當日累積 \(woolG) 克羊毛" : "當日無資料")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Text(hasAnyDayData ? FeedbackCaptions.caption(for: woolG) : "這一天還沒有任務、羊毛或任務記錄。")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            ShareLink(item: shareText) {
                Label("分享至外部", systemImage: "square.and.arrow.up")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.primary.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("當日任務紀錄")
                    .font(Theme.sectionTitleFont)
                    .foregroundStyle(Theme.primaryText)

                Text("保留換日存檔當下的任務狀態，以閱讀與回顧為主。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if dayTasks.isEmpty {
                emptyTaskState
            } else {
                ForEach(groupedTasks) { group in
                    if !group.tasks.isEmpty {
                        taskGroupSection(group)
                    }
                }
            }
        }
    }

    private func taskGroupSection(_ group: DailyTaskGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(group.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("\(group.tasks.count)")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(group.tint.opacity(0.35), in: Capsule())
            }

            ForEach(group.tasks) { task in
                HistoryTaskCard(
                    task: task,
                    logs: logsForTask(task)
                )
            }
        }
    }

    private var emptyTaskState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(Theme.surfaceLavender.opacity(0.72))

            Text("當日無資料")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            Text("這一天還沒有任務狀態或 Task Record 可以回顧。")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .softFeedbackCard(surface: .white.opacity(0.58))
    }

    private func logsForTask(_ task: TodoTask) -> [TaskLog] {
        dayLogs
            .filter { $0.taskID == task.id }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

private struct DailyTaskGroup: Identifiable {
    let id: String
    let title: String
    let tint: Color
    let tasks: [TodoTask]

    static func grouped(tasks: [TodoTask]) -> [DailyTaskGroup] {
        let sorted = tasks.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name < rhs.name
        }

        return [
            DailyTaskGroup(id: "done", title: "已完成", tint: Theme.surfaceLeaf, tasks: sorted.filter { $0.status == "done" }),
            DailyTaskGroup(id: "split", title: "已拆分", tint: Theme.surfaceLavender, tasks: sorted.filter { $0.status == "split" }),
            DailyTaskGroup(id: "started", title: "已開始", tint: Theme.primary, tasks: sorted.filter { $0.status == "started" }),
            DailyTaskGroup(id: "notStarted", title: "未開始", tint: Theme.tertiaryText, tasks: sorted.filter { $0.status == "notStarted" })
        ]
    }
}

private struct HistoryTaskCard: View {
    let task: TodoTask
    let logs: [TaskLog]

    private var progressText: String {
        "\(Int(task.progress * 100))%"
    }

    private var statusText: String {
        switch task.status {
        case "done": return "已完成"
        case "split": return "已拆分"
        case "started": return "已開始"
        case "notStarted": return "未開始"
        case "archived": return "已封存"
        default: return task.status
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 卡片 Header：保留任務基本資訊，但不放任何任務操作按鈕。
            header

            // 歷史進度：只讀 progress，讓使用者知道當日存檔時推進到哪裡。
            readOnlyProgress

            // 視覺重點：Task Record 面積加大，方便直接閱讀當時留下的紀錄。
            taskRecordArea
        }
        .padding(20)
        .softFeedbackCard(surface: .white.opacity(0.64))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(task.name)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if task.isMustToday {
                        Text("今日必完成")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.highlight.opacity(0.35), in: Capsule())
                    }

                    ComplexityBattery(complexity: task.complexity)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            FlowTagRow(tags: tagItems)
        }
    }

    private var readOnlyProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("存檔進度")
                Spacer()
                Text(progressText)
            }
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(Theme.secondaryText)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceMint.opacity(0.48))
                    Capsule()
                        .fill(task.status == "done" ? Theme.surfaceLeaf : Theme.primary)
                        .frame(width: geo.size.width * min(max(task.progress, 0), 1))
                }
            }
            .frame(height: 9)
        }
    }

    private var taskRecordArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("任務記錄")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text("\(logs.count) 則")
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if logs.isEmpty {
                Text("沒有留下文字紀錄")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                    .padding(16)
                    .background(recordBackground)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(logs) { log in
                        recordEntry(log)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            }
        }
    }

    private var tagItems: [HistoryTagItem] {
        var items = [HistoryTagItem(text: statusText, color: statusColor)]

        if let category = task.category, !category.isEmpty {
            items.append(HistoryTagItem(text: category, color: categoryColor))
        }

        if let subcategory = task.subcategory, !subcategory.isEmpty {
            items.append(HistoryTagItem(text: subcategory, color: categoryColor.opacity(0.78)))
        }

        return items
    }

    private func recordEntry(_ log: TaskLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(logTypeText(log.type))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                Spacer()
                Text(log.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(Theme.secondaryText)

            Text(log.content)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recordBackground)
    }

    private var recordBackground: some View {
        RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .fill(Theme.background.opacity(0.9))
    }

    private var statusColor: Color {
        switch task.status {
        case "done": return Theme.surfaceLeaf
        case "split": return Theme.surfaceLavender
        case "started": return Theme.primary
        default: return Theme.tertiaryText.opacity(0.55)
        }
    }

    private var categoryColor: Color {
        guard let colorHex = task.colorHex else { return Theme.primary }
        return Color(hex: colorHex) ?? Theme.primary
    }

    private func logTypeText(_ type: String) -> String {
        switch type {
        case "startNote": return "開始紀錄"
        case "chatSummary": return "卡關摘要"
        case "completion": return "完成回饋"
        case "split": return "拆分紀錄"
        default: return "任務紀錄"
        }
    }
}

private struct HistoryTagItem: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

private struct FlowTagRow: View {
    let tags: [HistoryTagItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tags) { item in
                Text(item.text)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.primaryText.opacity(0.78))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(item.color.opacity(0.32), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Color(hex:) moved to Components/Theme.swift (shared, one declaration per module).

#Preview {
    NavigationStack {
        DailyFeedbackView(date: Date())
    }
    .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
