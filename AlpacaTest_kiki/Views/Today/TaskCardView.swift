//
//  TaskCardView.swift
//  AlpacaTest_kiki
//
//  Action task card (TOD-03). Owned by A.
//  Step 4: 按鈕全部接上 — TOD-04 開始詢問、SPL-01~04 拆分、STK-01/02 卡關、
//  TOD-07 任務記錄、TSK-06 刪除確認。所有確認框都走共用的 ConfirmModal 樣板（COM-06）。
//  「編輯」已接上 TaskEditorView(task:) 編輯模式（TSK-05），卡片內不再有 placeholder。
//  Deferred: must-today tag, subcategory line, visual polish.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var task: TodoTask

    /// 拆分流程要由「不會消失的祖先」來呈現，不能由這張卡自己 present。
    /// 拆分成功後 task.status 變成 "split"，卡片會從「待辦」區搬到「已拆分」區
    /// ——那是兩個不同的 ForEach 子樹，卡片會被銷毀、@State 一起消失，
    /// SPL-04「拆分完成」就會在使用者按「確定」之前自己關掉。
    /// 由 TodayView 提供這個 callback；nil 時退回自己 present（給 Preview 用）。
    var onRequestSplit: ((TodoTask, SplitSource) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    // MARK: - Step 4 routing state

    /// 全螢幕蓋版：三個 ConfirmModal 系列（透明底）＋ 卡關聊天室
    private enum CardCover: Identifiable {
        case startAsk        // TOD-04
        case stuckConfirm    // STK-01
        case deleteConfirm   // TSK-06
        case stuckChat       // STK-02

        var id: Int {
            switch self {
            case .startAsk:      return 0
            case .stuckConfirm:  return 1
            case .deleteConfirm: return 2
            case .stuckChat:     return 3
            }
        }
    }

    /// Sheet：拆分流程（要帶 source）、任務記錄、編輯
    private enum CardSheet: Identifiable {
        case split(SplitSource)  // SPL-01~04
        case record              // TOD-07
        case edit                // TSK-05

        var id: String {
            switch self {
            case .split(let source): return "split-\(source)"
            case .record:            return "record"
            case .edit:              return "edit"
            }
        }
    }

    @State private var cover: CardCover?
    @State private var sheet: CardSheet?

    private var isStarted: Bool { task.status != "notStarted" }
    private var isDone: Bool    { task.status == "done" }

    /// SPL-05: a task that has been split into subtasks becomes a read-only parent —
    /// greyed out, progress not draggable, no action buttons, record viewing only.
    private var isSplitParent: Bool { task.status == "split" }

    // 分類色條：colorHex →（沒有的話）依分類名稱回推 → 都沒有才用預設強調色。
    // 舊資料只有 category、沒有 colorHex，靠第二段才不會整排同色。
    private var categoryColor: Color {
        CategoryColor.color(colorHex: task.colorHex, category: task.category)
    }

    var body: some View {
        HStack(spacing: 14) {
            // 1. 分類色條
            RoundedRectangle(cornerRadius: 3)
                .fill(categoryColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 16) {
                // 標題區：名稱 →（必完成標籤 · 子分類）＋ 右側電量
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.name)
                            .font(.alpacaHeading)
                            .foregroundStyle(Color.alpacaBrown)
                            .strikethrough(isDone)
                            .fixedSize(horizontal: false, vertical: true)

                        if task.isMustToday || task.subcategory != nil {
                            HStack(spacing: 8) {
                                if task.isMustToday {
                                    TagChip(text: "⚡️ 今日必完成", color: .alpacaOrange)
                                }

                                if let subcategory = task.subcategory {
                                    Text(subcategory)
                                        .font(.alpacaCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // 狀況備註：卡片上只給一行預覽，完整內容在編輯器／任務記錄裡
                        if let note = task.note, !note.isEmpty {
                            Text(note)
                                .font(.alpacaCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: 0)

                    ComplexityBattery(complexity: task.complexity)
                }

                // 進度條：一般卡片可拉（COM-02）；已拆分母任務唯讀（SPL-05）
                VStack(alignment: .leading, spacing: 6) {
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
                    HStack(spacing: 12) {
                        Text("已拆分成子任務")
                            .font(.alpacaCaption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        splitParentMenu
                    }
                } else {
                    // 只留兩個 inline 按鈕，其餘收進「…」——四顆並排會把中文標籤擠成兩行
                    HStack(spacing: 12) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
        // MARK: - Step 4 routing
        // 一個 cover + 一個 sheet，用 enum 分流。堆疊多個 .sheet/.fullScreenCover
        // 在同一層是 SwiftUI 的已知雷（只有部分會真的彈出），所以收斂成兩個。
        .fullScreenCover(item: $cover) { destination in
            coverContent(for: destination)
        }
        .sheet(item: $sheet) { destination in
            sheetContent(for: destination)
        }
    }

    // MARK: - Routing destinations

    @ViewBuilder
    private func coverContent(for destination: CardCover) -> some View {
        switch destination {
        case .startAsk:
            // TOD-04：否 → 照 Step 1 直接開始；是 → C 的 SplitFlowModal(.startAsk)
            StartAskSplitModal(
                onSplit: {
                    cover = nil
                    requestSplit(.startAsk)
                },
                onStartDirectly: {
                    cover = nil
                    start()
                }
            )
            .presentationBackground(.clear)

        case .stuckConfirm:
            // STK-01：C 已經把換字版 ConfirmModal 包好了
            StuckConfirmModal(
                onGo: { cover = .stuckChat },
                onCancel: { cover = nil }
            )
            .presentationBackground(.clear)

        case .deleteConfirm:
            // TSK-06：共用樣板，destructive 版
            DimmedModal {
                ConfirmModal(
                    title: "確定刪除這個任務嗎？",
                    message: "刪除後就找不回來了，相關的任務記錄也會一起消失。",
                    primary: ModalAction(title: "刪除", isDestructive: true) {
                        cover = nil
                        deleteTask()
                    },
                    secondary: ModalAction(title: "取消") { cover = nil }
                )
            }
            .presentationBackground(.clear)

        case .stuckChat:
            StuckChatView(task: task)
        }
    }

    @ViewBuilder
    private func sheetContent(for destination: CardSheet) -> some View {
        switch destination {
        case .split(let source):
            SplitFlowModal(task: task, source: source)
        case .record:
            TaskRecordSheet(task: task)
        case .edit:
            // TSK-05：共用編輯器，帶入既有任務 → 只改不新增
            TaskEditorView(task: task)
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
                cover = .stuckConfirm
            } label: {
                Label("卡住了", systemImage: "hand.raised.fill")
            }
            .disabled(isDone)

            if !isStarted {
                Button {
                    requestSplit(.manual)
                } label: {
                    Label("拆分", systemImage: "square.split.2x2")
                }
            }

            Divider()

            Button {
                sheet = .edit
            } label: {
                Label("編輯", systemImage: "pencil")
            }

            Button {
                sheet = .record
            } label: {
                Label("查看任務記錄", systemImage: "list.bullet.rectangle")
            }

            Button(role: .destructive) {
                cover = .deleteConfirm
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
                sheet = .record
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

    /// 開始前先問 TOD-04；開始後主要按鈕直接進手動拆分（SPL-01 .manual）
    /// 交給祖先 present；沒有 callback（Preview）才自己來。
    private func requestSplit(_ source: SplitSource) {
        if let onRequestSplit {
            onRequestSplit(task, source)
        } else {
            sheet = .split(source)
        }
    }

    private func primaryAction() {
        if isStarted {
            requestSplit(.manual)
        } else {
            cover = .startAsk
        }
    }

    /// TSK-06：先關掉 modal 再刪，避免 sheet 還持有已刪除的 model object。
    private func deleteTask() {
        let target = task
        DispatchQueue.main.async {
            modelContext.delete(target)
            try? modelContext.save()
        }
    }

    private func start() {
        task.status = "started"
        task.progress = max(task.progress, 0.2)          // COM-02: auto 0.2 on start
        // Wool is added ONLY through RewardEngine (§1.4).
        RewardEngine.grant(task.parentID != nil ? .startSubtask : .startTask(task.complexity), context: modelContext)
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
    notStarted.subcategory = "居家"
    notStarted.colorHex = "#D9733F"
    notStarted.complexity = 1
    notStarted.isMustToday = true
    notStarted.note = "抽屜那疊收據還沒分類，先從左邊第一格開始就好"

    let started = TodoTask(name: "讀日文三小時")
    started.category = "學習"
    started.subcategory = "日文"
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
