//
//  AddTaskView.swift
//  AlpacaTest_kiki
//
//  Minimal task creator. Owned by A.
//  Phase 1: migrated onto TodoTask (name + must-today + complexity).
//  TODO(Phase 2): rename to TaskEditorView (shared create/edit, COM-04), 3-state date (TSK-02),
//  inline category/subcategory creation, context note.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var isMustToday: Bool = false
    @State private var complexity: Int = 0        // 0 easy / 1 medium / 2 hard

    private let complexityLabels = ["簡單", "中等", "困難"]

    var body: some View {
        NavigationStack {
            Form {
                Section("任務名稱") {
                    TextField("例如：整理書桌", text: $name)
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
