//
//  TaskEditorView.swift
//  AlpacaTest_kiki
//
//  Shared create/edit task editor (TSK-01/05, COM-04). Owned by A.
//  init(task: nil) = 建立模式；init(task: someTask) = 編輯模式（欄位預先填入）。
//  編輯模式只改既有物件，不會再 insert 一筆。
//
//  TODO(Batch 2): 分類／子分類 picker（含 inline 新增）、情境備註。
//

import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// nil = 建立新任務；非 nil = 編輯這一筆
    private let task: TodoTask?

    /// TSK-02 的三種日期狀態。對應 Models 的規則：
    /// startDate 有值 = 已排程；nil + isUrgent = 未排但緊急；nil + !isUrgent = 未排不緊急。
    private enum DateState: Int, CaseIterable {
        case scheduled          // 指定日期
        case unscheduledUrgent  // 未排日期但緊急
        case unscheduledLater   // 未排日期不緊急

        var label: String {
            switch self {
            case .scheduled:         return "指定日期"
            case .unscheduledUrgent: return "未排・緊急"
            case .unscheduledLater:  return "未排・不急"
            }
        }
    }

    @State private var name: String
    @State private var isMustToday: Bool
    @State private var complexity: Int
    @State private var dateState: DateState
    @State private var startDate: Date

    private let complexityLabels = ["簡單", "中等", "困難"]

    init(task: TodoTask? = nil) {
        self.task = task

        _name        = State(initialValue: task?.name ?? "")
        _isMustToday = State(initialValue: task?.isMustToday ?? false)
        _complexity  = State(initialValue: task?.complexity ?? 0)
        _startDate   = State(initialValue: task?.startDate ?? Calendar.current.startOfDay(for: .now))

        // 從既有任務反推日期狀態；建立模式預設「指定日期（今天）」
        let resolvedDateState: DateState
        if let task {
            if task.startDate != nil    { resolvedDateState = .scheduled }
            else if task.isUrgent       { resolvedDateState = .unscheduledUrgent }
            else                        { resolvedDateState = .unscheduledLater }
        } else {
            resolvedDateState = .scheduled
        }
        _dateState = State(initialValue: resolvedDateState)
    }

    // MARK: - Mode

    private var isEditing: Bool { task != nil }
    private var screenTitle: String { isEditing ? "編輯任務" : "新增任務" }
    private var confirmTitle: String { isEditing ? "儲存變更" : "建立任務" }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// TOD-02 只讓選今天以後。但編輯一筆本來就排在過去的任務時，
    /// 下限要放寬到它自己的日期，否則 DatePicker 會把日期悄悄改掉。
    private var earliestSelectableDate: Date {
        let today = Calendar.current.startOfDay(for: .now)
        if let existing = task?.startDate, existing < today {
            return Calendar.current.startOfDay(for: existing)
        }
        return today
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任務名稱") {
                    TextField("例如：整理書桌", text: $name)
                }

                Section("日期") {
                    Picker("日期狀態", selection: $dateState) {
                        ForEach(DateState.allCases, id: \.self) { state in
                            Text(state.label).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)

                    // 只有「指定日期」才顯示日曆
                    if dateState == .scheduled {
                        DatePicker("開始日期",
                                   selection: $startDate,
                                   in: earliestSelectableDate...,
                                   displayedComponents: .date)
                    }
                }

                Section("設定") {
                    Toggle("今天一定要完成 ⚡️", isOn: $isMustToday)

                    Picker("複雜程度", selection: $complexity) {
                        ForEach(complexityLabels.indices, id: \.self) { index in
                            Text(complexityLabels[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(screenTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        // 編輯模式改既有物件；建立模式才 insert 一筆新的
        let target: TodoTask
        if let task {
            target = task
        } else {
            let created = TodoTask(name: trimmedName)
            modelContext.insert(created)
            target = created
        }

        target.name = trimmedName
        target.isMustToday = isMustToday
        target.complexity = complexity

        // TSK-02：三種狀態只靠 startDate / isUrgent 兩個欄位表達
        switch dateState {
        case .scheduled:
            target.startDate = Calendar.current.startOfDay(for: startDate)
            target.isUrgent = false
        case .unscheduledUrgent:
            target.startDate = nil
            target.isUrgent = true
        case .unscheduledLater:
            target.startDate = nil
            target.isUrgent = false
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview("建立") {
    TaskEditorView(task: nil)
        .modelContainer(for: TodoTask.self, inMemory: true)
}

#Preview("編輯") {
    let existing = TodoTask(name: "讀日文三小時")
    existing.subcategory = "日文"
    existing.complexity = 2
    existing.isMustToday = true
    existing.startDate = Calendar.current.startOfDay(for: .now)

    return TaskEditorView(task: existing)
        .modelContainer(for: TodoTask.self, inMemory: true)
}
