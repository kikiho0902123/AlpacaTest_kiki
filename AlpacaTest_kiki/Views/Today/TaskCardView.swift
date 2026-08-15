//
//  TaskCardView.swift
//  AlpacaTest_kiki
//
//  Action task card (TOD-03). Owned by A.
//  Phase 1: minimal migration onto TodoTask + RewardEngine/events.
//  TODO(Phase 3): StartAskSplitModal (TOD-04), Stuck entry (STK-01), record sheet, split-parent variant.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var task: TodoTask
    @Environment(\.modelContext) private var modelContext

    private var isDone: Bool    { task.status == "done" }
    private var isStarted: Bool { task.status != "notStarted" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 名稱 + 閃電 + 電量圖示
            HStack(alignment: .top) {
                Text(task.name)
                    .font(.alpacaHeading)
                    .foregroundStyle(Color.alpacaBrown)
                    .strikethrough(isDone)

                Spacer()

                HStack(spacing: 8) {
                    if task.isMustToday {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.alpacaOrange)
                    }
                    ComplexityBattery(complexity: task.complexity)
                }
            }

            if let category = task.category {
                TagChip(text: category)
            }

            // 可拉的進度條：手動回報完成度
            VStack(alignment: .leading, spacing: 4) {
                Slider(value: $task.progress, in: 0...1, step: 0.01)
                    .tint(isDone ? Color.alpacaGreen : Color.alpacaTerracotta)
                    .disabled(isDone)

                Text("完成度 \(Int(task.progress * 100))%")
                    .font(.alpacaCaption)
                    .foregroundStyle(.secondary)
            }

            // 操作按鈕列：開始 / 完成
            HStack(spacing: 10) {
                Button(action: start) {
                    Label("開始", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.alpacaBrown)
                .disabled(isStarted)

                Button(action: complete) {
                    Label("完成", systemImage: "checkmark")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.alpacaGreen)
                .disabled(isDone)

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .stroke(Color.alpacaBeige, lineWidth: 1.5)
        )
        .opacity(isDone ? 0.6 : 1.0)
        .animation(.easeInOut, value: task.status)
    }

    // MARK: - Actions

    private func start() {
        task.status = "started"
        task.progress = max(task.progress, 0.2)          // COM-02: auto 0.2 on start
        // Wool is added ONLY through RewardEngine (§1.4).
        RewardEngine.grant(task.parentID != nil ? .startSubtask : .startTask, context: modelContext)
    }

    private func complete() {
        NotificationCenter.default.post(name: .taskCompleted, object: task.id)
    }
}

#Preview {
    let task = TodoTask(name: "整理書桌")
    task.isMustToday = true
    task.complexity = 1
    return TaskCardView(task: task)
        .padding()
        .background(Color.alpacaCream)
        .modelContainer(for: TodoTask.self, inMemory: true)
}
