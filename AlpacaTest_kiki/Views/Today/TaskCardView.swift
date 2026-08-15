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

    /// SPL-05: a task that has been split into subtasks becomes a read-only parent —
    /// greyed out, progress not draggable, no action buttons, record viewing only.
    private var isSplitParent: Bool { task.status == "split" }

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

                // 進度條：一般卡片可拉（COM-02）；已拆分母任務唯讀（SPL-05）
                VStack(alignment: .leading, spacing: 4) {
                    if isSplitParent {
                        ProgressBarView(progress: task.progress, isDone: isDone)
                    } else {
                        Slider(value: $task.progress, in: 0...1, step: 0.01)
                            .tint(isDone ? Color.alpacaGreen : Color.alpacaTerracotta)
                            .disabled(isDone)
                    }

                    Text("完成度 \(Int(task.progress * 100))%")
                        .font(.alpacaCaption)
                        .foregroundStyle(.secondary)
                }

                // 操作按鈕列：已拆分母任務只留「…」→ 查看任務記錄（SPL-05）
                if isSplitParent {
                    HStack(spacing: 10) {
                        Text("已拆分成子任務")
                            .font(.alpacaCaption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        splitParentMenu
                    }
                } else {
                    // 只留兩個 inline 按鈕，其餘收進「…」——四顆並排會把中文標籤擠成兩行
                    HStack(spacing: 10) {
                        // 主要按鈕：開始 →（開始後）拆分
                        Button(action: primaryAction) {
                            Label(isStarted ? "拆分" : "開始",
                                  systemImage: isStarted ? "square.split.2x2" : "play.fill")
                                .font(.subheadline)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.alpacaBrown)
                        .disabled(isDone)

                        Button(action: complete) {
                            Label("完成", systemImage: "checkmark")
                                .font(.subheadline)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.alpacaGreen)
                        .disabled(isDone)

                        Spacer()

                        actionMenu
                    }
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
        .opacity(cardOpacity)
        .animation(.easeInOut, value: task.status)
        // 進度拉到 1.0 也視為完成 → 交給 B 的完成流程
        // isDone 檔掉重複發送：CompletionView.finish() 會把 progress 寫成 1.0，
        // 那次寫入同樣會觸發這個 onChange，若不擋就會二次發 .taskCompleted（重複發羊毛）。
        // 已拆分母任務的進度由子任務推動，不該觸發完成流程（SPL-05）。
        .onChange(of: task.progress) { oldValue, newValue in
            guard !isDone, !isSplitParent else { return }
            if oldValue < 1.0 && newValue >= 1.0 { postCompleted() }
        }
    }

    /// 已完成與已拆分都是灰階唯讀狀態
    private var cardOpacity: Double {
        if isDone { return 0.6 }
        if isSplitParent { return 0.65 }
        return 1.0
    }

    /// 一般卡片的「…」：卡住了／拆分＋Step 4 才接的編輯／刪除／查看記錄。
    /// 拆分只在還沒開始時出現——開始之後主要按鈕本身就是「拆分」，不重複給入口。
    private var actionMenu: some View {
        Menu {
            Button {
                print("卡住了 tapped — TODO Step 4 (StuckConfirmModal)")
            } label: {
                Label("卡住了", systemImage: "hand.raised.fill")
            }
            .disabled(isDone)

            if !isStarted {
                Button {
                    print("拆分 tapped — TODO Step 4 (SplitFlowModal source: .manual)")
                } label: {
                    Label("拆分", systemImage: "square.split.2x2")
                }
            }

            Divider()

            Button {
                print("編輯 tapped — TODO Step 4 (TaskEditorView)")
            } label: {
                Label("編輯", systemImage: "pencil")
            }

            Button {
                print("查看任務記錄 tapped — TODO Step 4 (C's TaskRecordSheet, TOD-07)")
            } label: {
                Label("查看任務記錄", systemImage: "list.bullet.rectangle")
            }

            Button(role: .destructive) {
                print("刪除 tapped — TODO Step 4 (ConfirmModal, TSK-06)")
            } label: {
                Label("刪除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(Color.alpacaBrown)
    }

    /// SPL-05：只保留「查看任務記錄」，不提供編輯／刪除／開始等動作
    private var splitParentMenu: some View {
        Menu {
            Button {
                print("查看任務記錄 tapped — TODO Step 4 (C's TaskRecordSheet, TOD-07)")
            } label: {
                Label("查看任務記錄", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(Color.alpacaBrown)
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

    // SPL-05：已拆分母任務，唯讀灰階、只有「…」→ 查看任務記錄
    let splitParent = TodoTask(name: "準備專題期中報告")
    splitParent.category = "學校"
    splitParent.colorHex = "#BAB7CD"
    splitParent.complexity = 2
    splitParent.status = "split"
    splitParent.progress = 0.4

    return ScrollView {
        VStack(spacing: 16) {
            TaskCardView(task: notStarted)
            TaskCardView(task: started)
            TaskCardView(task: splitParent)
        }
        .padding()
    }
    .background(Color.alpacaCream)
    .modelContainer(for: TodoTask.self, inMemory: true)
}
