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

    /// 現有分類是從所有任務的 category 去重來的（TSK-03：沒有獨立的分類資料表）
    @Query private var allTasks: [TodoTask]

    @State private var name: String
    @State private var note: String
    @State private var isMustToday: Bool
    @State private var complexity: Int
    @State private var dateState: DateState
    @State private var startDate: Date

    @State private var category: String?          // nil = 無分類
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""

    private let complexityLabels = ["簡單", "中等", "困難"]

    init(task: TodoTask? = nil) {
        self.task = task

        _category    = State(initialValue: task?.category)
        _name        = State(initialValue: task?.name ?? "")
        _note        = State(initialValue: task?.note ?? "")
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

    // MARK: - 分類（TSK-03）

    /// 所有任務用過的分類，去重排序。沒有分類資料表，這就是唯一來源。
    private var availableCategories: [String] {
        Set(allTasks.compactMap { $0.category })
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    private var trimmedNewCategory: String {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 新分類建立後立刻選起來
    private func commitNewCategory() {
        let name = trimmedNewCategory
        guard !name.isEmpty else { return }
        category = name
        isAddingCategory = false
        newCategoryName = ""
    }

    private func cancelNewCategory() {
        isAddingCategory = false
        newCategoryName = ""
    }

    /// 分類要配哪個顏色：同分類已經有人用過就沿用，否則照現有分類數量循環調色盤。
    private func colorHex(for category: String) -> String {
        if let existing = allTasks.first(where: { $0.category == category && $0.colorHex != nil })?.colorHex {
            return existing
        }

        let categories = availableCategories
        if let index = categories.firstIndex(of: category) {
            return CategoryColor.hex(atIndex: index)
        }
        // 全新的分類 → 接在現有分類後面拿下一個色
        return CategoryColor.hex(atIndex: categories.count)
    }

    /// 空白備註存成 nil，不存空字串——這樣卡片和記錄頁只要判斷 nil 就好
    private var normalizedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

                Section("分類") {
                    Picker("分類", selection: $category) {
                        Text("無分類").tag(String?.none)
                        ForEach(availableCategories, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }

                    if isAddingCategory {
                        // 「＋新增分類」被點下去後，這一列就變成輸入框（TSK-03）
                        HStack {
                            TextField("新分類名稱", text: $newCategoryName)
                                .submitLabel(.done)
                                .onSubmit { commitNewCategory() }

                            Button("確定") { commitNewCategory() }
                                .buttonStyle(.borderless)
                                .disabled(trimmedNewCategory.isEmpty)

                            Button("取消") { cancelNewCategory() }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            isAddingCategory = true
                        } label: {
                            Label("新增分類", systemImage: "plus.circle")
                        }
                    }
                }

                Section("狀況備註") {
                    TextField("這個任務目前的狀況、卡點、或想記住的事",
                              text: $note,
                              axis: .vertical)
                        .lineLimit(3...5)
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
        target.note = normalizedNote

        // TSK-03：分類決定色條顏色，一併把 colorHex 寫進去
        target.category = category
        target.colorHex = category.map { colorHex(for: $0) }
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
