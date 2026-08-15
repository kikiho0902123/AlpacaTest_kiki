//
//  TodayTasksView.swift
//  AlpacaTest_kiki
//
//  Today main screen (TOD-01). Owned by A.
//  Phase 1: minimal migration onto TodoTask.
//  TODO(Phase 2): rename to TodayView, extract AlpacaStatusView (image only, no numbers — STATE-09),
//  three groups (To-do / Split / Done).
//

import SwiftUI
import SwiftData

struct TodayTasksView: View {
    @Query(sort: \TodoTask.createdAt) private var allTasks: [TodoTask]
    @Query(sort: \DailyStat.date) private var allStats: [DailyStat]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("home.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("home.eodReminderMinutes") private var eodReminderMinutes = 21 * 60

    @State private var showAddSheet = false
    @State private var completingTaskID: UUID?
    @State private var eodRequest: EODRequest?

    private var calendar: Calendar { Calendar.current }

    // 未完成在前，已完成在後
    private var sortedTasks: [TodoTask] {
        allTasks.sorted { lhs, rhs in
            let lDone = lhs.status == "done"
            let rDone = rhs.status == "done"
            if lDone != rDone { return !lDone }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var completingTask: TodoTask? {
        guard let completingTaskID else { return nil }
        return allTasks.first { $0.id == completingTaskID }
    }

    private var shouldShowEODIsland: Bool {
        notificationsEnabled && currentMinutes >= eodReminderMinutes
    }

    private var currentMinutes: Int {
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.alpacaCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // AlpacaStatusView placeholder — image only, NO numbers, NO caption (STATE-09).
                        Image(systemName: "pawprint.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(Color.alpacaOrange)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity)

                        if shouldShowEODIsland {
                            eodIsland
                                .padding(.horizontal)
                        }

                        if sortedTasks.isEmpty {
                            Text("今天還沒有任務，點右下角加號新增一個吧！")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                                .padding(.horizontal, 32)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(sortedTasks) { task in
                                TaskCardView(task: task)
                                    .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 80)
                    }
                }

                Button {
                    showAddSheet = true
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
        }
        .sheet(isPresented: $showAddSheet) {
            AddTaskView()
        }
        .sheet(isPresented: completionSheetBinding) {
            if let completingTask {
                CompletionView(task: completingTask) {
                    completingTaskID = nil
                }
            }
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

struct EODRequest: Identifiable {
    let id = UUID()
    let date: Date
    let isAutoRollover: Bool
}

#Preview {
    TodayTasksView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
