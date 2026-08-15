//
//  TaskRecordSheet.swift
//  [C 擁有 — 明天複製到 repo 的 Views/Chat/TaskRecordSheet.swift]
//
//  TOD-07 Task Record 查看：該任務累積的所有記錄時間軸（開始備註、
//  卡關 Summary、完成備註、拆分記錄），Bottom Sheet 形式。
//  呼叫方式：.sheet { TaskRecordSheet(task: task) }
//

import SwiftUI
import SwiftData

struct TaskRecordSheet: View {
    let task: TodoTask
    @Query private var logs: [TaskLog]

    init(task: TodoTask) {
        self.task = task
        let tid = task.id
        _logs = Query(filter: #Predicate<TaskLog> { $0.taskID == tid },
                      sort: \TaskLog.timestamp)
    }

    private func meta(for type: String) -> (label: String, icon: String) {
        switch type {
        case "startNote":      ("開始備註", "play.circle")
        case "chatSummary":    ("卡關解套記錄", "bubble.left.and.bubble.right")
        case "completion":     ("完成備註", "checkmark.circle")
        case "split":          ("任務拆分", "arrow.triangle.branch")
        case "noHelpFeedback": ("回饋", "hand.thumbsdown")
        default:               ("記錄", "note.text")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ChatTheme.cream.ignoresSafeArea()
                if logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("這個任務還沒有任何記錄")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(logs, id: \.id) { log in
                        let m = meta(for: log.type)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(m.label, systemImage: m.icon)
                                    .font(.caption.bold())
                                    .foregroundStyle(ChatTheme.terracotta)
                                Spacer()
                                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(log.content)
                                .font(.subheadline)
                                .foregroundStyle(ChatTheme.brown)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.85))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("任務記錄")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])          // Bottom Sheet（TOD-07）
    }
}
