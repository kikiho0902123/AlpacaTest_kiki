//
//  EODFlow.swift
//  AlpacaTest_kiki
//
//  End-of-day achievement, sharing, harvest, and rollover flow (EOD-02~08). Owned by B.
//

import SwiftUI
import SwiftData

struct EODAchievementModal: View {
    var settlementDate: Date = Date()
    var isAutoRollover: Bool = false
    let onCancel: () -> Void
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStat.date) private var stats: [DailyStat]
    @Query(sort: \TodoTask.createdAt) private var tasks: [TodoTask]
    @Query private var profiles: [UserProfile]

    @State private var phase: EODPhase = .achievement
    @State private var harvestScale = 1.0
    @State private var harvestOpacity = 1.0
    @State private var showShareTemplates = false

    private var calendar: Calendar { Calendar.current }

    private var settlementStat: DailyStat {
        if let stat = stats.first(where: { calendar.isDate($0.date, inSameDayAs: settlementDate) }) {
            return stat
        }

        let stat = DailyStat(date: settlementDate)
        modelContext.insert(stat)
        return stat
    }

    private var settlementWool: Int {
        settlementStat.woolG
    }

    private var settlementAlpacaTier: Int {
        AlpacaFeedbackSnapshot.tierForRecordedActions(
            startCount: settlementStat.startCount,
            stuckCount: settlementStat.stuckCount,
            doneCount: settlementStat.doneCount
        )
    }

    private var settlementTasks: [TodoTask] {
        tasks.filter { task in
            calendar.isDate(task.createdAt, inSameDayAs: settlementDate)
                || task.startDate.map { calendar.isDate($0, inSameDayAs: settlementDate) } == true
                || task.status == "done"
        }
    }

    private var biggestTaskText: String {
        let doneTasks = settlementTasks.filter { $0.status == "done" }
        guard let task = doneTasks.max(by: { RewardEngine.woolFor(.complete($0.complexity)) < RewardEngine.woolFor(.complete($1.complexity)) }) else {
            return "今天還沒有完成任務，羊駝仍然有好好陪你。"
        }

        return "最大成果：\(task.name)"
    }

    private var shareSummary: EODShareSummary {
        EODShareSummary(
            date: settlementDate,
            woolG: settlementWool,
            caption: FeedbackCaptions.caption(for: settlementWool),
            biggestTask: biggestTaskText,
            alpacaTier: settlementAlpacaTier,
            startCount: settlementStat.startCount,
            stuckCount: settlementStat.stuckCount,
            doneCount: settlementStat.doneCount
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch phase {
            case .achievement:
                achievementView
            case .harvesting:
                harvestingView
            case .harvestDone:
                harvestDoneView
            case .rollover:
                rolloverView
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showShareTemplates) {
            EODShareTemplateView(summary: shareSummary)
        }
    }

    private var achievementView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                if isAutoRollover {
                    Text("前一個工作日結算")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceLavender.opacity(0.28), in: Capsule())
                }

                AlpacaFeedbackSnapshot(woolG: settlementWool, size: 150, growthTier: settlementAlpacaTier)

                Text("收集了 \(settlementWool) g")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(FeedbackCaptions.caption(for: settlementWool))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(biggestTaskText)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                tallyItem(title: "開始", count: settlementStat.startCount, color: Theme.surfaceMint)
                tallyItem(title: "卡關", count: settlementStat.stuckCount, color: Theme.surfaceLavender)
                tallyItem(title: "完成", count: settlementStat.doneCount, color: Theme.surfaceLeaf)
            }

            VStack(spacing: 10) {
                Button {
                    startHarvest()
                } label: {
                    Text("收割羊毛")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button {
                    showShareTemplates = true
                } label: {
                    Label("分享至外部", systemImage: "square.and.arrow.up")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }

                if !isAutoRollover {
                    Button("取消") {
                        onCancel()
                    }
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
        .softFeedbackCard(surface: .white.opacity(0.62))
        .padding(24)
    }

    private var harvestingView: some View {
        VStack(spacing: 18) {
            AlpacaFeedbackSnapshot(woolG: settlementWool, size: 156, growthTier: settlementAlpacaTier)
                .scaleEffect(harvestScale)
                .opacity(harvestOpacity)

            Text("正在收割羊毛")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(28)
        .softFeedbackCard(surface: .white.opacity(0.62))
        .padding(24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8)) {
                harvestScale = 0.78
                harvestOpacity = 0.35
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                commitHarvest()
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .harvestDone
                }
            }
        }
    }

    private var harvestDoneView: some View {
        VStack(spacing: 18) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.primary)

            Text("\(settlementWool) g 羊毛已存入羊毛庫")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .rollover
                }
            } label: {
                Text("完成")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.primary.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(28)
        .softFeedbackCard(surface: .white.opacity(0.62))
        .padding(24)
    }

    private var rolloverView: some View {
        ConfirmModal(
            title: "恭喜進入新的一天",
            message: "現在你可以建立新的任務，或到任務庫將已建立的任務拖動到今天的日期。",
            primary: ModalAction(title: "完成") {
                openActiveWorkdayIfNeeded()
                onFinished()
            }
        )
    }

    private func tallyItem(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.45), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
    }

    private func startHarvest() {
        harvestScale = 1.0
        harvestOpacity = 1.0
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .harvesting
        }
    }

    private func commitHarvest() {
        guard !settlementStat.harvested else { return }

        let profile = profiles.first ?? UserProfile()
        if profiles.isEmpty {
            modelContext.insert(profile)
        }

        profile.woolBankG += settlementStat.woolG
        settlementStat.harvested = true
        settlementStat.isClosed = true
        try? modelContext.save()
    }

    private func openActiveWorkdayIfNeeded() {
        let activeDate = Date()
        let hasActive = stats.contains { calendar.isDate($0.date, inSameDayAs: activeDate) && !$0.isClosed }
        if !hasActive {
            modelContext.insert(DailyStat(date: activeDate))
        }

        try? modelContext.save()
    }
}

struct EODShareTemplateView: View {
    let summary: EODShareSummary

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate = EODShareTemplate.full

    private var shareText: String {
        switch selectedTemplate {
        case .full:
            return "AlpacaTask｜\(summary.date.formatted(.dateTime.month().day())) 收集 \(summary.woolG) g。\(summary.biggestTask)。開始 \(summary.startCount)、卡關 \(summary.stuckCount)、完成 \(summary.doneCount)。"
        case .simple:
            return "AlpacaTask｜今天收集 \(summary.woolG) g 羊毛。\(summary.caption)"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Picker("模板", selection: $selectedTemplate) {
                    ForEach(EODShareTemplate.allCases) { template in
                        Text(template.title).tag(template)
                    }
                }
                .pickerStyle(.segmented)

                TabView(selection: $selectedTemplate) {
                    shareCard(template: .full)
                        .tag(EODShareTemplate.full)
                    shareCard(template: .simple)
                        .tag(EODShareTemplate.simple)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack(spacing: 12) {
                    ShareLink(item: shareText) {
                        Label("分享至其他 App", systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.primary.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Button {
                        // Batch implementation: uses OS share text; image saving can reuse this template later.
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .accessibilityLabel("儲存圖片")
                }
            }
            .padding(22)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("分享成果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(Theme.primaryText)
                }
            }
        }
    }

    private func shareCard(template: EODShareTemplate) -> some View {
        VStack(spacing: 18) {
            AlpacaFeedbackSnapshot(woolG: summary.woolG, size: template == .full ? 132 : 156, growthTier: summary.alpacaTier)

            Text("\(summary.woolG) g")
                .font(.system(template == .full ? .title : .largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            Text(summary.caption)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            if template == .full {
                Text(summary.biggestTask)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    miniTally("開始", summary.startCount, Theme.surfaceMint)
                    miniTally("卡關", summary.stuckCount, Theme.surfaceLavender)
                    miniTally("完成", summary.doneCount, Theme.surfaceLeaf)
                }
            }

            Text("AlpacaTask")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private func miniTally(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct EODShareSummary {
    let date: Date
    let woolG: Int
    let caption: String
    let biggestTask: String
    let alpacaTier: Int
    let startCount: Int
    let stuckCount: Int
    let doneCount: Int
}

enum EODShareTemplate: String, CaseIterable, Identifiable {
    case full
    case simple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "完整模板"
        case .simple: return "簡易模板"
        }
    }
}

private enum EODPhase {
    case achievement
    case harvesting
    case harvestDone
    case rollover
}

#Preview {
    EODAchievementModal(onCancel: {}, onFinished: {})
        .modelContainer(for: [TodoTask.self, DailyStat.self, UserProfile.self], inMemory: true)
}
