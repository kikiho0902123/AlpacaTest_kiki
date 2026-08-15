//
//  StuckChatView.swift
//  [C 擁有 — 明天複製到 repo 的 Views/Chat/StuckChatView.swift]
//
//  STK-02 卡關解套聊天室（8 輪）＋ STK-03 離開確認 ＋ STK-04 Summary ＋ STK-05 沒幫助回饋。
//  輪次規則：round = 使用者訊息數 + 1（R1 = AI 開場）。R8 回覆後鎖輸入（STK-02H）；
//  safety 觸發不受 8 輪限制。從聊天進拆分且完成 → 自動走「離開並記錄」（設計師 04 §10）。
//  呼叫方式：.fullScreenCover { StuckChatView(task: task) }（STK-01 確認由呼叫端先彈）
//

import SwiftUI
import SwiftData

struct StuckChatView: View {
    let task: TodoTask

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sessionID = UUID()
    @State private var thread: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentReply: StuckReply?
    @State private var safetyActive = false
    @State private var splitEnded = false
    @State private var showSplit = false
    @State private var showExitConfirm = false
    @State private var summaryText: String?
    @State private var showNoHelp = false
    @State private var noHelpText = ""

    private var userCount: Int { thread.filter { $0.role == "user" }.count }
    private var round: Int { min(userCount + 1, 8) }
    /// STK-02H：第 8 輪（第 7 則使用者訊息的回覆）之後鎖輸入；safety 不受限
    private var isLocked: Bool { userCount >= 7 && !safetyActive }

    var body: some View {
        NavigationStack {
            ZStack {
                ChatTheme.cream.ignoresSafeArea()
                VStack(spacing: 0) {
                    messageList
                    bottomArea
                }
            }
            .navigationTitle(task.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("離開") { showExitConfirm = true }
                }
            }
        }
        .interactiveDismissDisabled()                    // 離開一律走 STK-03 確認
        .task { await requestReply() }                   // R1 開場
        .sheet(isPresented: $showSplit) {
            SplitFlowModal(task: task, source: .fromChat, chatContext: thread) {
                splitEnded = true
                exitAndRecord()                          // 拆分完成 = 本次卡關解套結束點
            }
        }
        .overlay {
            if showExitConfirm {
                DimmedModal {
                    ConfirmModal(
                        title: "離開聊天室嗎？",
                        message: "離開前會把這次對話整理成一段記錄，存進任務的 Task Record。",
                        primary: ModalAction(title: "離開並記錄內容") { showExitConfirm = false; exitAndRecord() },
                        secondary: ModalAction(title: "取消") { showExitConfirm = false }
                    )
                }
            }
            if let summary = summaryText {
                SummaryModal(text: summary,
                             onHelpful: { dismiss() },
                             onNotHelpful: { summaryText = nil; showNoHelp = true })
            }
            if showNoHelp {
                NoHelpFeedbackModal(
                    feedbackText: $noHelpText,
                    onDone: {
                        let trimmed = noHelpText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            modelContext.insert(TaskLog(taskID: task.id, type: "noHelpFeedback", content: trimmed))
                            try? modelContext.save()
                        }
                        dismiss()
                    },
                    onSkip: { dismiss() }
                )
            }
        }
    }

    // MARK: - 對話區

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(thread, id: \.id) { msg in
                        ChatBubble(role: msg.role, text: msg.content)
                    }
                    if isLoading { TypingBubble() }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .onChange(of: thread.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: - 底部：拆分推薦 / 輕量選項 / chips / 輸入框

    private var bottomArea: some View {
        VStack(spacing: 10) {
            // STK-02F 拆分推薦（AI 判斷符合條件才出現）
            if currentReply?.recommendSplit == true && !splitEnded && !isLocked && !isLoading {
                HStack(spacing: 8) {
                    Button("幫我拆分任務") { showSplit = true }
                        .buttonStyle(.borderedProminent)
                        .tint(ChatTheme.terracotta)
                    Button("先不要，我想繼續聊") {
                        currentReply?.recommendSplit = false
                    }
                    .buttonStyle(.bordered)
                    .tint(ChatTheme.brown)
                }
                .font(.subheadline)
            }

            // R2+ 輕量選項（點了直接送出）
            if let opts = currentReply?.quickOptions, !opts.isEmpty,
               userCount > 0, !isLocked, !isLoading {
                QuickOptionsRow(options: opts) { send($0) }
            }

            // R1 卡點 chips（預設寫死；AI 有給就用 AI 的）
            if userCount == 0 && !thread.isEmpty && !isLoading {
                ChipsRow(chips: StuckChips.resolve(aiProvided: currentReply?.quickOptions ?? []),
                         inputText: $inputText)
            }

            if isLocked {
                Label("今天聊得夠深了，AI 需要休息 15 分鐘。把上面的下一步帶走吧 🌿", systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            HStack(spacing: 8) {
                TextField(isLocked ? "AI 休息中…" : "輸入訊息…", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLocked || isLoading)
                Button {
                    send(inputText)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(ChatTheme.terracotta))
                }
                .disabled(isLocked || isLoading ||
                          inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    // MARK: - 動作

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading, !isLocked else { return }
        if SafetyGate.isTriggered(trimmed) { safetyActive = true }

        let msg = ChatMessage(taskID: task.id, sessionID: sessionID, role: "user", content: trimmed)
        modelContext.insert(msg)
        thread.append(msg)
        inputText = ""
        Task { await requestReply() }
    }

    private func requestReply() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let history = ScoringEngine.relevantHistory(for: task, context: modelContext)
            let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?
                .first?.onboardingJSON ?? "{}"
            let reply = try await AIService.shared.stuckChat(
                task: task, round: round, messages: thread,
                history: history, profileJSON: profile)
            currentReply = reply
            let msg = ChatMessage(taskID: task.id, sessionID: sessionID,
                                  role: "assistant", content: reply.text)
            modelContext.insert(msg)
            thread.append(msg)
            try? modelContext.save()
        } catch {
            let msg = ChatMessage(taskID: task.id, sessionID: sessionID, role: "assistant",
                                  content: "（連線出了點問題：\(error.localizedDescription)。可以再試一次，或先離開並記錄。）")
            modelContext.insert(msg)
            thread.append(msg)
        }
    }

    /// STK-03「離開並記錄」→ summarize → 寫 TaskLog(chatSummary) → grant → STK-04
    private func exitAndRecord() {
        Task {
            isLoading = true
            var summary: String
            do { summary = try await AIService.shared.summarize(messages: thread) }
            catch { summary = "這次聊了「\(task.name)」的卡點。（AI 摘要暫時失敗，先以此記錄）" }
            if splitEnded { summary += "（此次對話最後決定將原任務拆分。）" }

            // 若因拆分結束，Summary 記到母任務 = 本聊天的 task 本身（契約規則）
            modelContext.insert(TaskLog(taskID: task.id, type: "chatSummary", content: summary))
            RewardEngine.grant(.stuckChatDone, context: modelContext)
            try? modelContext.save()
            isLoading = false
            summaryText = summary                        // → STK-04
        }
    }
}
