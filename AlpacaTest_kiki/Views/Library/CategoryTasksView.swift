//
//  CategoryTasksView.swift
//  AlpacaTest_kiki
//
//  LIB-C03 分類頁：該分類的任務，依子分類分組（nil → 未安排子分類）。Owned by A.
//  純瀏覽；點任務開共用編輯器（TaskEditorView 編輯模式）。
//  沒有拖拉、沒有清單編輯模式、沒有分類 CRUD。
//

import SwiftUI
import SwiftData

struct CategoryTasksView: View {
    let category: String?          // nil = 未分類
    var accent: Color = .alpacaTerracotta

    @Query(sort: \TodoTask.sortOrder) private var allTasks: [TodoTask]
    @State private var editingTask: TodoTask?

    private var tasks: [TodoTask] {
        allTasks.filter { $0.status != "archived" && $0.category == category }
    }

    /// 依子分類分組，nil 的收到「未安排子分類」並排在最後
    private var groups: [(title: String, tasks: [TodoTask])] {
        let grouped = Dictionary(grouping: tasks) { $0.subcategory }

        return grouped
            .map { subcategory, tasks in
                (title: subcategory ?? "未安排子分類", tasks: tasks, isNil: subcategory == nil)
            }
            .sorted { lhs, rhs in
                if lhs.isNil != rhs.isNil { return !lhs.isNil }
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
            .map { (title: $0.title, tasks: $0.tasks) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if tasks.isEmpty {
                    Text("這個分類還沒有任務")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    ForEach(groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(group.title)
                                    .font(Theme.sectionTitleFont)
                                    .foregroundStyle(Color.alpacaBrown.opacity(0.75))

                                Text("\(group.tasks.count)")
                                    .font(.alpacaCaption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 10) {
                                ForEach(group.tasks) { task in
                                    Button {
                                        editingTask = task
                                    } label: {
                                        LibraryTaskRow(task: task, accent: accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.alpacaCream.ignoresSafeArea())
        .navigationTitle(category ?? "未分類")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
        }
    }
}

// MARK: - 未排日期清單

struct UnscheduledTasksView: View {
    let group: UnscheduledGroup

    @Query(sort: \TodoTask.sortOrder) private var allTasks: [TodoTask]
    @State private var editingTask: TodoTask?

    private var tasks: [TodoTask] {
        allTasks.filter {
            $0.status != "archived"
                && $0.startDate == nil
                && $0.isUrgent == (group == .urgent)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if tasks.isEmpty {
                    Text("這一組目前沒有任務")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } else {
                    Text("點任務可以指定日期，排進今日任務")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(tasks) { task in
                        Button {
                            editingTask = task
                        } label: {
                            LibraryTaskRow(
                                task: task,
                                accent: group == .urgent ? Color.alpacaStuck : Color.alpacaBrown.opacity(0.4)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.alpacaCream.ignoresSafeArea())
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
        }
    }
}

// MARK: - Shared row

/// 任務庫的唯讀列。刻意不用 TaskCardView —— 那張卡帶著開始／完成／拆分等動作，
/// 這裡只要瀏覽。
struct LibraryTaskRow: View {
    let task: TodoTask
    var accent: Color = .alpacaTerracotta

    private var isDone: Bool { task.status == "done" }

    private var statusLabel: String? {
        switch task.status {
        case "started": return "進行中"
        case "split":   return "已拆分"
        case "done":    return "已完成"
        default:        return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.name)
                    .font(.alpacaBody)
                    .foregroundStyle(Color.alpacaBrown)
                    .strikethrough(isDone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if task.isMustToday {
                        Text("⚡️")
                            .font(.alpacaCaption)
                    }

                    if let statusLabel {
                        Text(statusLabel)
                            .font(.alpacaCaption)
                            .foregroundStyle(.secondary)
                    }

                    if let startDate = task.startDate {
                        Text(startDate.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_Hant_TW"))))
                            .font(.alpacaCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            ComplexityBattery(complexity: task.complexity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .opacity(isDone ? 0.6 : 1)
    }
}

#Preview {
    NavigationStack {
        CategoryTasksView(category: "學習")
    }
    .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
