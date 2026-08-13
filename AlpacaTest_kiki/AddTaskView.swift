//
//  AddTaskView.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var isMustDoToday: Bool = false
    @State private var difficulty: TaskDifficulty = .easy

    var body: some View {
        NavigationStack {
            Form {
                Section("任務名稱") {
                    TextField("例如：整理書桌", text: $name)
                }

                Section("設定") {
                    Toggle("今天一定要完成 ⚡️", isOn: $isMustDoToday)

                    Picker("複雜程度", selection: $difficulty) {
                        ForEach(TaskDifficulty.allCases) { level in
                            Text(level.label).tag(level)
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
                        let newTask = TaskItem(name: name, isMustDoToday: isMustDoToday, difficulty: difficulty)
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
        .modelContainer(for: TaskItem.self, inMemory: true)
}
