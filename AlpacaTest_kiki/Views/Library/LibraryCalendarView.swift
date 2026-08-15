//
//  LibraryCalendarView.swift
//  AlpacaTest_kiki
//
//  任務庫 by-time（LIB-T01 月曆 / LIB-T02 單日總覽）。Owned by A.
//  純瀏覽：不能拖拉、不能在格子上編輯。點某一天才開單日總覽。
//
//  時區：完全照 TodayView.todayPredicate() 的做法 —— Calendar.current 的
//  startOfDay 當下界、半開區間 [start, end)。日期存的是 UTC，本地換算錯一個
//  小時就會整批任務跑到前一天。不要自己另外發明一套。
//
//  只有 startDate 有意義（任務沒有結束日），所以一個任務只會出現在一格。
//

import SwiftUI
import SwiftData

struct LibraryCalendarView: View {
    /// 目前顯示的月份（該月一號的 startOfDay）
    @State private var monthAnchor: Date = CalendarMath.startOfMonth(for: .now)
    @State private var selectedDay: DaySelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            monthHeader

            weekdayHeader

            // .id 讓月份一換就重建 → 內部的 @Query 會用新的月份區間重跑
            MonthGrid(monthAnchor: monthAnchor) { day in
                selectedDay = DaySelection(date: day)
            }
            .id(monthAnchor)

            UnscheduledStrip()
        }
        .sheet(item: $selectedDay) { selection in
            DayTasksSheet(day: selection.date)
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Color.alpacaBrown)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(CalendarMath.monthTitle(for: monthAnchor))
                .font(.alpacaTitle)
                .foregroundStyle(Color.alpacaBrown)

            Spacer()

            // 過去和未來都能翻 —— 這裡是瀏覽歷史，不套 TOD-02 的今天以後限制
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.alpacaBrown)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(CalendarMath.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.alpacaCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func shiftMonth(by delta: Int) {
        guard let shifted = CalendarMath.calendar.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            monthAnchor = CalendarMath.startOfMonth(for: shifted)
        }
    }
}

/// sheet(item:) 需要 Identifiable
struct DaySelection: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

// MARK: - Month grid

/// 一個月的格子。@Query 在 init 就綁定「這個月可見範圍」的區間，
/// 所以整個月只查一次，不是每格查一次。
private struct MonthGrid: View {
    let monthAnchor: Date
    let onSelectDay: (Date) -> Void

    @Query private var tasks: [TodoTask]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(monthAnchor: Date, onSelectDay: @escaping (Date) -> Void) {
        self.monthAnchor = monthAnchor
        self.onSelectDay = onSelectDay

        // 可見範圍包含前後月補齊的日子，一次查完
        let range = CalendarMath.visibleRange(for: monthAnchor)
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

    /// 依「本地當天」把任務分桶，key 是 startOfDay
    private var tasksByDay: [Date: [TodoTask]] {
        Dictionary(grouping: tasks.filter { $0.status != "archived" }) { task in
            CalendarMath.calendar.startOfDay(for: task.startDate ?? .now)
        }
    }

    var body: some View {
        let days = CalendarMath.gridDays(for: monthAnchor)
        let byDay = tasksByDay

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    day: day,
                    isInDisplayedMonth: CalendarMath.isSameMonth(day, as: monthAnchor),
                    isToday: CalendarMath.calendar.isDateInToday(day),
                    tasks: byDay[day] ?? []
                )
                .onTapGesture { onSelectDay(day) }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let tasks: [TodoTask]

    private let maxChips = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(CalendarMath.calendar.component(.day, from: day))")
                .font(.system(.caption, design: .rounded).weight(isToday ? .bold : .regular))
                .foregroundStyle(dayNumberColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isToday ? Color.alpacaTerracotta : .clear)
                )

            ForEach(tasks.prefix(maxChips)) { task in
                TaskChip(task: task)
            }

            if tasks.count > maxChips {
                Text("+\(tasks.count - maxChips)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isInDisplayedMonth ? 0.75 : 0.35))
        )
        .opacity(isInDisplayedMonth ? 1 : 0.45)
        .contentShape(Rectangle())
    }

    private var dayNumberColor: Color {
        if isToday { return .white }
        return isInDisplayedMonth ? Color.alpacaBrown : Color.alpacaBrown.opacity(0.5)
    }
}

/// 格子裡的任務 chip：色點 + 截斷的名稱。這個尺寸下只用來看，不能點。
private struct TaskChip: View {
    let task: TodoTask

    private var dotColor: Color {
        if let hex = task.colorHex, let color = Color(hex: hex) { return color }
        return .alpacaTerracotta
    }

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)

            Text(task.name)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(task.status == "done" ? Color.alpacaBrown.opacity(0.45) : Color.alpacaBrown)
                .strikethrough(task.status == "done")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)   // 點擊一律交給整個格子
    }
}

// MARK: - 未排日期（橫向）

private struct UnscheduledStrip: View {
    @Query(sort: \TodoTask.sortOrder) private var allTasks: [TodoTask]
    @State private var editingTask: TodoTask?

    private var urgent: [TodoTask] {
        allTasks.filter { $0.status != "archived" && $0.startDate == nil && $0.isUrgent }
    }

    private var later: [TodoTask] {
        allTasks.filter { $0.status != "archived" && $0.startDate == nil && !$0.isUrgent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("未排日期")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Color.alpacaBrown.opacity(0.75))

            if urgent.isEmpty && later.isEmpty {
                Text("目前每個任務都有日期")
                    .font(.alpacaCaption)
                    .foregroundStyle(.secondary)
            } else {
                group(title: "緊急", tasks: urgent, accent: .alpacaStuck)
                group(title: "不緊急", tasks: later, accent: Color.alpacaBrown.opacity(0.4))
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
        }
    }

    @ViewBuilder
    private func group(title: String, tasks: [TodoTask], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.alpacaBody)
                    .foregroundStyle(Color.alpacaBrown)
                Text("\(tasks.count)")
                    .font(.alpacaCaption)
                    .foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                Text("沒有任務")
                    .font(.alpacaCaption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tasks) { task in
                            Button {
                                editingTask = task
                            } label: {
                                UnscheduledPill(task: task, accent: accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct UnscheduledPill: View {
    let task: TodoTask
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.alpacaCaption)
                    .foregroundStyle(Color.alpacaBrown)
                    .lineLimit(1)

                if let subcategory = task.subcategory {
                    Text(subcategory)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 190, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }
}

#Preview {
    ScrollView {
        LibraryCalendarView()
            .padding()
    }
    .background(Color.alpacaCream)
    .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
