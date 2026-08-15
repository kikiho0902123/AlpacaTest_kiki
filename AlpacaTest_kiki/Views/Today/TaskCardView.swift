//
//  TaskCardView.swift
//  AlpacaTest_kiki
//
//  Action task card (TOD-03). Owned by A.
//  Step 1: working minimum — blocks B (History variant) and C (SplitFlowModal subtask cards).
//  Deferred: must-today tag, subcategory line, split-parent variant, visual polish.
//  Empty buttons (拆分 / 卡住了 / …) print() only — wired in Step 4.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var task: TodoTask
    @Environment(\.modelContext) private var modelContext

    private var isStarted: Bool { task.status != "notStarted" }
    private var isDone: Bool    { task.status == "done" }

    // 分類色條：優先用 task.colorHex，否則回退主題強調色
    private var categoryColor: Color {
        if let hex = task.colorHex, let color = Color(hex: hex) { return color }
        return .alpacaTerracotta
    }

    var body: some View {
        HStack(spacing: 12) {
            // 1. 分類色條
            RoundedRectangle(cornerRadius: 3)
                .fill(categoryColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                // 名稱 + 電量圖示
                HStack(alignment: .top) {
                    Text(task.name)
                        .font(.alpacaHeading)
                        .foregroundStyle(Color.alpacaBrown)
                        .strikethrough(isDone)

                    Spacer()

                    ComplexityBattery(complexity: task.complexity)
                }

                // 可拉的進度條：手動回報完成度（COM-02，百分比保留）
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $task.progress, in: 0...1, step: 0.01)
                        .tint(isDone ? Color.alpacaGreen : Color.alpacaTerracotta)
                        .disabled(isDone)

                    Text("完成度 \(Int(task.progress * 100))%")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                }

                // 操作按鈕列
                HStack(spacing: 10) {
                    // 主要按鈕：開始 →（開始後）拆分
                    Button(action: primaryAction) {
                        Label(isStarted ? "拆分" : "開始",
                              systemImage: isStarted ? "square.split.2x2" : "play.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.alpacaBrown)
                    .disabled(isDone)

                    Button(action: complete) {
                        Label("完成", systemImage: "checkmark")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.alpacaGreen)
                    .disabled(isDone)

                    Spacer()

                    Button {
                        print("卡住了 tapped — TODO Step 4 (StuckConfirmModal)")
                    } label: {
                        Label("卡住了", systemImage: "hand.raised.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.alpacaStuck)
                    .disabled(isDone)

                    Button {
                        print("… menu tapped — TODO Step 4 (Edit / Delete / View record)")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.alpacaBrown)
                }
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
        // 進度拉到 1.0 也視為完成 → 交給 B 的完成流程
        // isDone 檔掉重複發送：CompletionView.finish() 會把 progress 寫成 1.0，
        // 那次寫入同樣會觸發這個 onChange，若不擋就會二次發 .taskCompleted（重複發羊毛）。
        .onChange(of: task.progress) { oldValue, newValue in
            guard !isDone else { return }
            if oldValue < 1.0 && newValue >= 1.0 { postCompleted() }
        }
    }

    // MARK: - Actions

    private func primaryAction() {
        if isStarted {
            print("拆分 tapped — TODO Step 4 (SplitFlowModal source: .manual)")
        } else {
            start()
        }
    }

    private func start() {
        task.status = "started"
        task.progress = max(task.progress, 0.2)          // COM-02: auto 0.2 on start
        // Wool is added ONLY through RewardEngine (§1.4).
        RewardEngine.grant(task.parentID != nil ? .startSubtask : .startTask, context: modelContext)
    }

    /// Complete ONLY posts the event. B's flow (TOD-05 confirm → TOD-06 note)
    /// owns the status="done" transition and the .complete reward.
    private func complete() {
        postCompleted()
    }

    private func postCompleted() {
        NotificationCenter.default.post(name: .taskCompleted, object: task.id)
    }
}

#Preview {
    let notStarted = TodoTask(name: "整理書桌")
    notStarted.category = "生活"
    notStarted.colorHex = "#D9733F"
    notStarted.complexity = 1

    let started = TodoTask(name: "讀日文三小時")
    started.category = "學習"
    started.colorHex = "#6B8E5A"
    started.complexity = 2
    started.status = "started"
    started.progress = 0.2

    return ScrollView {
        VStack(spacing: 16) {
            TaskCardView(task: notStarted)
            TaskCardView(task: started)
        }
        .padding()
    }
    .background(Color.alpacaCream)
    .modelContainer(for: TodoTask.self, inMemory: true)
}
