//
//  TodayView.swift
//  AlpacaTest_kiki
//
//  Today main screen (TOD-01). Owned by A.
//  Step 2: date heading, today-only query sorted by sortOrder, three sections
//  (待辦 / 已拆分 / 已完成), alpaca extracted to AlpacaStatusView (STATE-09).
//
//  B's mechanisms are preserved as-is and built on top of, not rewritten:
//  EOD island (EOD-01), .taskCompleted → CompletionView listener, auto-rollover.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(filter: TodayView.todayPredicate(), sort: \TodoTask.sortOrder)
    private var todayTasks: [TodoTask]
    @Query(sort: \DailyStat.date) private var allStats: [DailyStat]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("home.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("home.eodReminderMinutes") private var eodReminderMinutes = 21 * 60

    @State private var showAddSheet = false          // 手動建立
    @State private var showCreateChoice = false      // 「＋」先問手動 or AI
    @State private var showAICreate = false          // AI 幫你建立
    @State private var completingTaskID: UUID?
    @State private var eodRequest: EODRequest?

    /// 拆分流程由 TodayView 呈現，不是由任務卡自己 present。
    /// 拆分成功會把 status 改成 "split"，卡片就從「待辦」搬到「已拆分」——
    /// 兩個不同子樹，卡片被銷毀，它 present 的 SPL-04「拆分完成」會跟著消失。
    /// TodayView 不會消失，所以由它持有這個 sheet。
    @State private var splitRequest: SplitRequest?

    // MARK: - Dev flags (remove/flip before shipping)

    /// EOD-01 requires the island to be ALWAYS VISIBLE during development.
    /// B's time gate (`eodReminderMinutes`, default 21:00) hides it during daytime
    /// rehearsals. Set to false to restore the real time-of-day behaviour.
    private static let alwaysShowEODIslandInDev = true

    /// EOD-02B/08 auto-rollover is Batch 3 scope (TEAM_PLAN §0), and it writes to the
    /// model from `.task` — i.e. on every appearance of the Today tab — so it can
    /// silently close a DailyStat mid-demo. Off until after the demo.
    private static let autoRolloverEnabled = false

    private var calendar: Calendar { Calendar.current }

    // MARK: - Today's window

    /// Today's tasks only: `startDate` inside [startOfDay, startOfTomorrow).
    /// C's split subtasks inherit the parent's `startDate`, so they land here too.
    private static func todayPredicate() -> Predicate<TodoTask> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start

        return #Predicate<TodoTask> { task in
            if let startDate = task.startDate {
                startDate >= start && startDate < end
            } else {
                false
            }
        }
    }

    // MARK: - Sections (TOD-01)

    private var todoTasks: [TodoTask] {
        todayTasks.filter { $0.status == "notStarted" || $0.status == "started" }
    }

    private var splitTasks: [TodoTask] {
        todayTasks.filter { $0.status == "split" }
    }

    private var doneTasks: [TodoTask] {
        todayTasks.filter { $0.status == "done" }
    }

    private var dateHeading: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    private var shouldShowEODIsland: Bool {
        guard notificationsEnabled else { return false }
        return Self.alwaysShowEODIslandInDev || currentMinutes >= eodReminderMinutes
    }

    private var currentMinutes: Int {
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var completingTask: TodoTask? {
        guard let completingTaskID else { return nil }
        return todayTasks.first { $0.id == completingTaskID }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.alpacaCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        // 羊駝只有圖，沒有數字、沒有文案（STATE-09）
                        AlpacaStatusView()

                        if shouldShowEODIsland {
                            eodIsland
                                .padding(.horizontal)
                        }

                        if todayTasks.isEmpty {
                            Text("今天還沒有任務，點右下角加號新增一個吧！")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                                .padding(.horizontal, 32)
                                .frame(maxWidth: .infinity)
                        } else {
                            section(title: "待辦", tasks: todoTasks)
                            section(title: "已拆分", tasks: splitTasks)
                            section(title: "已完成", tasks: doneTasks)
                        }

                        // 讓最後一張卡不被右下角浮動「＋」蓋住（＋ 高 56 + 下緣 20）
                        Spacer(minLength: 140)
                    }
                }

                Button {
                    showCreateChoice = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.alpacaTerracotta))
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("今日任務")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 「＋」→ 先選建立方式（共用 ConfirmModal 樣板，透明底蓋滿整頁）
        .fullScreenCover(isPresented: $showCreateChoice) {
            CreateTaskChoiceModal(
                onAI: {
                    showCreateChoice = false
                    showAICreate = true
                },
                onManual: {
                    showCreateChoice = false
                    showAddSheet = true
                }
            )
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showAddSheet) {
            TaskEditorView(task: nil)
        }
        .sheet(isPresented: $showAICreate) {
            AITaskCreationView()
        }
        .sheet(isPresented: completionSheetBinding) {
            if let completingTask {
                CompletionView(task: completingTask) {
                    completingTaskID = nil
                }
            }
        }
        .sheet(item: $splitRequest) { request in
            SplitFlowModal(task: request.task, source: request.source)
        }
        .sheet(item: $eodRequest) { request in
            EODAchievementModal(
                settlementDate: request.date,
                isAutoRollover: request.isAutoRollover,
                onCancel: { eodRequest = nil },
                onFinished: { eodRequest = nil }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { notification in
            if let taskID = notification.object as? UUID {
                completingTaskID = taskID
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayEnded)) { _ in
            eodRequest = EODRequest(date: Date(), isAutoRollover: false)
        }
        .task {
            openAutoRolloverIfNeeded()
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text(dateHeading)
                .font(.alpacaTitle)
                .foregroundStyle(Color.alpacaBrown)

            Spacer()

            // TOD-02 DatePickerModal 是 Batch 2；現在只是圖示，不開任何東西
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(Color.alpacaBrown.opacity(0.6))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func section(title: String, tasks: [TodoTask]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Theme.sectionTitleFont)
                    .foregroundStyle(Color.alpacaBrown.opacity(0.75))
                    .padding(.horizontal)

                ForEach(tasks) { task in
                    TaskCardView(task: task) { task, source in
                        splitRequest = SplitRequest(task: task, source: source)
                    }
                    .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var eodIsland: some View {
        Button {
            NotificationCenter.default.post(name: .dayEnded, object: nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.alpacaOrange)

                Text("結束今天，收割羊毛！")
                    .font(.alpacaHeading)
                    .foregroundStyle(Color.alpacaBrown)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.alpacaBrown.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.alpacaOrange.opacity(0.45), lineWidth: 1.2)
            )
            .shadow(color: Color.alpacaOrange.opacity(0.16), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var completionSheetBinding: Binding<Bool> {
        Binding(
            get: { completingTask != nil },
            set: { isPresented in
                if !isPresented {
                    completingTaskID = nil
                }
            }
        )
    }

    private func openAutoRolloverIfNeeded() {
        guard Self.autoRolloverEnabled else { return }

        let hour = calendar.component(.hour, from: Date())
        guard hour >= 5 else { return }
        guard eodRequest == nil else { return }

        let todayStart = calendar.startOfDay(for: Date())
        let unresolved = allStats
            .filter { stat in
                let statDay = calendar.startOfDay(for: stat.date)
                return statDay < todayStart && !stat.harvested
            }
            .sorted { $0.date > $1.date }
            .first

        if let unresolved {
            unresolved.isClosed = true
            try? modelContext.save()
            eodRequest = EODRequest(date: unresolved.date, isAutoRollover: true)
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
