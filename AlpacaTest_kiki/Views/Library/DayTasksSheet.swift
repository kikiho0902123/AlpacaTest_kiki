//
//  DayTasksSheet.swift
//  AlpacaTest_kiki
//
//  LIB-T02 單日任務總覽。Owned by A.
//  某一天的任務，照 TOD-01 的分區：待辦 / 已拆分 / 已完成。
//  點任務 → 共用的 TaskEditorView 編輯模式（專案裡沒有 TaskDetailSheet）。
//

import SwiftUI
import SwiftData

struct DayTasksSheet: View {
    let day: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [TodoTask]
    @State private var editingTask: TodoTask?

    init(day: Date) {
        self.day = day

        // 半開區間，跟 TodayView / 月曆同一套時區規則
        let range = CalendarMath.dayRange(for: day)
        let start = range.start
        let end = range.end

        _tasks = Query(
            filter: #Predicate<TodoTask> { task in
                if let startDate = task.startDate {
                    startDate >= start && startDate < end
                } else {
                    false
                }
            },
            sort: \TodoTask.sortOrder
        )
    }

    private var visibleTasks: [TodoTask] {
        tasks.filter { $0.status != "archived" }
    }

    private var todo: [TodoTask] {
        visibleTasks.filter { $0.status == "notStarted" || $0.status == "started" }
    }

    private var split: [TodoTask] {
        visibleTasks.filter { $0.status == "split" }
    }

    private var done: [TodoTask] {
        visibleTasks.filter { $0.status == "done" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if visibleTasks.isEmpty {
                        Text("這天沒有任務")
                            .font(.alpacaCaption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                    } else {
                        section(title: "待辦", tasks: todo)
                        section(title: "已拆分", tasks: split)
                        section(title: "已完成", tasks: done)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.alpacaCream.ignoresSafeArea())
            .navigationTitle(CalendarMath.dayTitle(for: day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
        }
    }

    @ViewBuilder
    private func section(title: String, tasks: [TodoTask]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Color.alpacaBrown.opacity(0.75))

                    Text("\(tasks.count)")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                }

                ForEach(tasks) { task in
                    Button {
                        editingTask = task
                    } label: {
                        LibraryTaskRow(task: task, accent: accent(for: task))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func accent(for task: TodoTask) -> Color {
        if let hex = task.colorHex, let color = Color(hex: hex) { return color }
        return .alpacaTerracotta
    }
}

#Preview {
    DayTasksSheet(day: .now)
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
