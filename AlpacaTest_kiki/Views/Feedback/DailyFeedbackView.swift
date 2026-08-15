//
//  DailyFeedbackView.swift
//  AlpacaTest_kiki
//
//  Daily feedback detail (FBK-03/04/05/09 entry). Owned by B.
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

    private var dayTasks: [TodoTask] {
        let loggedTaskIDs = Set(dayLogs.map(\.taskID))
        let matching = tasks.filter { task in
            loggedTaskIDs.contains(task.id)
                || calendar.isDate(task.createdAt, inSameDayAs: date)
                || task.startDate.map { calendar.isDate($0, inSameDayAs: date) } == true
        }

        return matching.sorted { lhs, rhs in
            let lhsPriority = statusPriority(lhs.status)
            let rhsPriority = statusPriority(rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var woolG: Int {
        dayStat?.woolG ?? 0
    }

    private var shareText: String {
        "\(date.formatted(.dateTime.month().day().weekday(.wide))) 累積 \(woolG) g 羊毛，完成 \(dayStat?.doneCount ?? 0) 件任務。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                daySummary
                taskSection
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("日回饋")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.primaryText)
                }
                .accessibilityLabel("分享至外部")
            }
        }
    }

    private var daySummary: some View {
        VStack(spacing: 18) {
            Text(date.formatted(.dateTime.year().month(.wide).day().weekday(.wide)))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            AlpacaFeedbackSnapshot(woolG: woolG, size: 136)

            VStack(spacing: 8) {
                Text("\(woolG) g")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Text(FeedbackCaptions.caption(for: woolG))
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
        VStack(alignment: .leading, spacing: 14) {
            Text("當日歷史任務")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

            if dayTasks.isEmpty {
                emptyTaskState
            } else {
                ForEach(dayTasks) { task in
                    HistoryTaskCard(
                        task: task,
                        logs: logsForTask(task)
                    )
                }
            }
        }
    }

    private var emptyTaskState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(Theme.surfaceLavender.opacity(0.72))

            Text("這天還沒有任務紀錄")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
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

    private func statusPriority(_ status: String) -> Int {
        switch status {
        case "done": return 0
        case "split": return 1
        case "started": return 2
        case "notStarted": return 3
        default: return 4
        }
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
            header
            readOnlyProgress
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
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Theme.highlight)
                            .accessibilityLabel("今日必完成")
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
                Text("完成度")
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
            Text("Task Record")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)

            if logs.isEmpty {
                Text("沒有留下文字紀錄")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .padding(14)
                    .background(recordBackground)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(logs) { log in
                        recordEntry(log)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
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
        VStack(alignment: .leading, spacing: 7) {
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
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(recordBackground)
    }

    private var recordBackground: some View {
        RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .fill(Theme.background.opacity(0.86))
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

private extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    NavigationStack {
        DailyFeedbackView(date: Date())
    }
    .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
