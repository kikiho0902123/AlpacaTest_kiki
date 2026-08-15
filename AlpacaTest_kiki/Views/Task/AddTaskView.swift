//
//  AddTaskView.swift
//  AlpacaTest_kiki
//
//  Minimal task creator. Owned by A.
//  Step 3: 加上 TSK-02 的三種日期狀態（指定日期／未排但緊急／未排不緊急）。
//  TODO(Batch 2): rename to TaskEditorView (shared create/edit, COM-04),
//  inline category/subcategory creation, context note, edit-mode prefill.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

    @State private var name: String = ""
    @State private var isMustToday: Bool = false
    @State private var complexity: Int = 0        // 0 easy / 1 medium / 2 hard
    @State private var dateState: DateState = .scheduled
    @State private var startDate: Date = Calendar.current.startOfDay(for: .now)

    private let complexityLabels = ["簡單", "中等", "困難"]

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
                                   in: Calendar.current.startOfDay(for: .now)...,
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
            .navigationTitle("新增任務")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let newTask = TodoTask(name: name)
                        newTask.isMustToday = isMustToday
                        newTask.complexity = complexity

                        // TSK-02：三種狀態只靠 startDate / isUrgent 兩個欄位表達
                        switch dateState {
                        case .scheduled:
                            newTask.startDate = Calendar.current.startOfDay(for: startDate)
                            newTask.isUrgent = false
                        case .unscheduledUrgent:
                            newTask.startDate = nil
                            newTask.isUrgent = true
                        case .unscheduledLater:
                            newTask.startDate = nil
                            newTask.isUrgent = false
                        }

                        modelContext.insert(newTask)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: TodoTask.self, inMemory: true)
}
