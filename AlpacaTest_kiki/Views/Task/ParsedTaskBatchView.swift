//
//  ParsedTaskBatchView.swift
//  AlpacaTest_kiki
//
//  顯示 AI 從一段描述解析出的多筆任務，確認後一次寫入 SwiftData。
//

import SwiftUI
import SwiftData

struct ParsedTaskBatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TodoTask]

    @State private var drafts: [ParsedTask]
    @State private var draftToEdit: DraftToEdit?
    @State private var saveError: String?
    @State private var isSaving = false

    private let onSaved: (() -> Void)?

    private struct DraftToEdit: Identifiable {
        let id = UUID()
        let index: Int
        let task: ParsedTask
    }

    init(tasks: [ParsedTask], onSaved: (() -> Void)? = nil) {
        _drafts = State(initialValue: tasks)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.alpacaCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    List {
                        Section {
                            ForEach(Array(drafts.enumerated()), id: \.offset) { index, task in
                                taskRow(task, index: index, number: index + 1)
                            }
                            .onDelete(perform: deleteDrafts)
                        } header: {
                            Text("AI 找到 \(drafts.count) 個任務")
                        } footer: {
                            Text("向左滑可以移除不想建立的任務。")
                        }
                    }
                    .scrollContentBackground(.hidden)

                    createButton
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.alpacaCream)
                }
            }
            .navigationTitle("確認任務清單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .alert("建立失敗", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("好", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "請稍後再試。")
            }
        }
        .sheet(item: $draftToEdit) { item in
            ParsedTaskDraftEditorView(task: item.task) { updated in
                guard drafts.indices.contains(item.index) else { return }
                drafts[item.index] = updated
            }
        }
    }

    private func taskRow(_ task: ParsedTask, index: Int, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.alpacaTerracotta)
                    .clipShape(Circle())

                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(Color.alpacaBrown)

                Spacer(minLength: 8)

                Button {
                    draftToEdit = DraftToEdit(index: index, task: task)
                } label: {
                    Label("編輯", systemImage: "pencil")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(Color.alpacaBrown)
            }

            HStack(spacing: 8) {
                if let date = task.startDate {
                    Label(
                        date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_Hant_TW"))),
                        systemImage: "calendar"
                    )
                } else {
                    Label("未排日期", systemImage: "calendar.badge.minus")
                }

                if let category = task.category {
                    Text(category)
                }

                Text(complexityLabel(task.complexity))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Label(
                task.isUrgent ? "緊急" : "一般",
                systemImage: task.isUrgent ? "exclamationmark.circle.fill" : "minus.circle"
            )
            .font(.caption.bold())
            .foregroundStyle(task.isUrgent ? Color.alpacaTerracotta : .secondary)

            if task.isMustToday {
                Label("今天一定要完成", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.alpacaTerracotta)
            }

            if let note = task.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Color.alpacaBrown.opacity(0.75))
            }
        }
        .padding(.vertical, 6)
    }

    private var createButton: some View {
        Button {
            saveAll()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().tint(Color.alpacaBrown)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(isSaving ? "正在建立…" : "建立 \(drafts.count) 個任務")
            }
            .font(.alpacaHeading)
            .foregroundStyle(Color.alpacaBrown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary.opacity(drafts.isEmpty ? 0.45 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(drafts.isEmpty || isSaving)
    }

    private func deleteDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    private func complexityLabel(_ value: Int) -> String {
        ["簡單", "中等", "困難"][max(0, min(value, 2))]
    }

    private func saveAll() {
        guard !drafts.isEmpty else { return }
        isSaving = true

        var knownColors: [String: String] = [:]
        for task in allTasks {
            if let category = task.category, let colorHex = task.colorHex {
                knownColors[category] = colorHex
            }
        }
        var categoryCount = Set(allTasks.compactMap(\.category)).count
        var nextSortOrder = (allTasks.map(\.sortOrder).max() ?? -1) + 1
        var inserted: [TodoTask] = []

        for draft in drafts {
            let task = TodoTask(name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines))
            task.startDate = draft.startDate.map { Calendar.current.startOfDay(for: $0) }
            task.isUrgent = draft.isUrgent
            task.isMustToday = draft.isMustToday
            task.complexity = max(0, min(draft.complexity, 2))
            task.category = normalized(draft.category)
            task.note = normalized(draft.note)
            task.sortOrder = nextSortOrder

            if let category = task.category {
                if let existing = knownColors[category] {
                    task.colorHex = existing
                } else {
                    let color = CategoryColor.hex(atIndex: categoryCount)
                    knownColors[category] = color
                    task.colorHex = color
                    categoryCount += 1
                }
            }

            modelContext.insert(task)
            inserted.append(task)
            nextSortOrder += 1
        }

        do {
            try modelContext.save()
            onSaved?()
            dismiss()
        } catch {
            for task in inserted { modelContext.delete(task) }
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// 只編輯記憶體裡的 AI 草稿；不會在這個 sheet 寫入 SwiftData。
private struct ParsedTaskDraftEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var isUrgent: Bool
    @State private var isMustToday: Bool
    @State private var complexity: Int
    @State private var category: String
    @State private var note: String

    private let onSave: (ParsedTask) -> Void
    private let complexityLabels = ["簡單", "中等", "困難"]

    init(task: ParsedTask, onSave: @escaping (ParsedTask) -> Void) {
        _name = State(initialValue: task.name)
        _hasStartDate = State(initialValue: task.startDate != nil)
        _startDate = State(initialValue: task.startDate ?? Calendar.current.startOfDay(for: .now))
        _isUrgent = State(initialValue: task.isUrgent)
        _isMustToday = State(initialValue: task.isMustToday)
        _complexity = State(initialValue: max(0, min(task.complexity, 2)))
        _category = State(initialValue: task.category ?? "")
        _note = State(initialValue: task.note ?? "")
        self.onSave = onSave
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任務名稱") {
                    TextField("任務名稱", text: $name)
                }

                Section("日期") {
                    Toggle("指定日期", isOn: $hasStartDate)

                    if hasStartDate {
                        DatePicker(
                            "開始日期",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section("設定") {
                    Toggle("緊急任務", isOn: $isUrgent)
                    Toggle("今天一定要完成 ⚡️", isOn: $isMustToday)

                    Picker("複雜程度", selection: $complexity) {
                        ForEach(complexityLabels.indices, id: \.self) { index in
                            Text(complexityLabels[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("分類") {
                    TextField("例如：工作、課業、生活", text: $category)
                }

                Section("狀況備註") {
                    TextField(
                        "任務脈絡、限制或卡點",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("編輯 AI 任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存修改") { saveDraft() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func saveDraft() {
        let calendar = Calendar.current
        let resolvedDate: Date?
        if isMustToday {
            resolvedDate = calendar.startOfDay(for: .now)
        } else if hasStartDate {
            resolvedDate = calendar.startOfDay(for: startDate)
        } else {
            resolvedDate = nil
        }

        onSave(ParsedTask(
            name: trimmedName,
            startDate: resolvedDate,
            isUrgent: isUrgent,
            isMustToday: isMustToday,
            complexity: complexity,
            category: normalized(category),
            note: normalized(note)
        ))
        dismiss()
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    ParsedTaskBatchView(tasks: [
        ParsedTask(
            name: "經濟學期末報告",
            startDate: Calendar.current.date(byAdding: .day, value: 3, to: .now),
            complexity: 2,
            category: "課業",
            note: "完全沒頭緒"
        ),
        ParsedTask(
            name: "準備健行用品",
            isUrgent: true,
            isMustToday: true,
            complexity: 0,
            category: "生活"
        )
    ])
    .modelContainer(for: TodoTask.self, inMemory: true)
}
