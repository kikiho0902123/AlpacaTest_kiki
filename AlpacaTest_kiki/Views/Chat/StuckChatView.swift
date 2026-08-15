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
    /// AI 每輪的內部分析。只活在這次 session（不寫資料庫），下一輪回餵給 AI，
    /// 也給拆分與摘要當作「這次到底卡在哪」的依據。使用者永遠看不到。
    @State private var analysis: ContextAnalysis?
    @State private var safetyActive = false
    @State private var splitEnded = false
    @State private var showSplit = false
    @State private var showExitConfirm = false
    @State private var summaryText: String?
    @State private var showNoHelp = false
    @State private var noHelpText = ""
    /// onAppear 會重複觸發，用旗標確保 R1 只發一次
    @State private var didOpen = false

    private var userCount: Int { thread.filter { $0.role == "user" }.count }
    private var round: Int { min(userCount + 1, 8) }
    /// STK-02H：第 8 輪（第 7 則使用者訊息的回覆）之後鎖輸入；safety 不受限
    private var isLocked: Bool { userCount >= 7 && !safetyActive }
    /// 有實際互動才值得記錄：使用者說過話，或這次真的把任務拆了。
    /// 一進來就按離開的話，不該打摘要 API、不該寫 TaskLog、更不該發羊毛。
    private var hasRealConversation: Bool { userCount > 0 || splitEnded }

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
        // R1 開場。這裡不能用 .task {}：它的生命週期綁在 view 上，而 fullScreenCover
        // 在彈出過程中會重建內容 view，第一個請求會被取消（console 出現 URLError.cancelled），
        // 於是降級成罐頭——使用者就看到一則罐頭開場白。改用不綁 view 的 Task {}。
        .onAppear {
            guard !didOpen else { return }               // onAppear 會重複觸發
            didOpen = true
            Task { await requestReply() }
        }
        .sheet(isPresented: $showSplit) {
            SplitFlowModal(task: task, source: .fromChat, chatContext: thread, analysis: analysis) {
                splitEnded = true
                exitAndRecord()                          // 拆分完成 = 本次卡關解套結束點
            }
        }
        .overlay {
            if showExitConfirm {
                DimmedModal {
                    if hasRealConversation {
                        ConfirmModal(
                            title: "離開聊天室嗎？",
                            message: "離開前會把這次對話整理成一段記錄，存進任務的 Task Record。",
                            primary: ModalAction(title: "離開並記錄內容") { showExitConfirm = false; exitAndRecord() },
                            secondary: ModalAction(title: "取消") { showExitConfirm = false }
                        )
                    } else {
                        // 還沒開口就想走：沒有東西可以摘要，直接放人
                        ConfirmModal(
                            title: "離開聊天室嗎？",
                            message: "你還沒開始聊，離開不會留下任何記錄。",
                            primary: ModalAction(title: "離開") { showExitConfirm = false; dismiss() },
                            secondary: ModalAction(title: "取消") { showExitConfirm = false }
                        )
                    }
                }
            }
            if let summary = summaryText {
                SummaryModal(text: summary,
                             onHelpful: {
                                 // 契約只定義了 noHelpFeedback，但「有幫助」不留下任何痕跡等於丟資料。
                                 // 寫一筆 chatHelpful，B 的回饋頁要不要顯示由 B 決定（不顯示也無害）。
                                 modelContext.insert(TaskLog(taskID: task.id, type: "chatHelpful",
                                                             content: "使用者標記這次卡關解套有幫助"))
                                 try? modelContext.save()
                                 dismiss()
                             },
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

            // §04：R5–7 若已經得到足夠協助，不需要硬撐到 R8。
            // AI 判斷 readyToClose 就給一個明確的出口，但不強制——使用者想繼續聊還是可以。
            if currentReply?.analysis?.readyToClose == true,
               !isLocked, !isLoading, !splitEnded {
                Button {
                    showExitConfirm = true
                } label: {
                    Label("這次先到這裡", systemImage: "leaf.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(ChatTheme.brown)
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
                history: history, profileJSON: profile,
                previous: analysis)
            currentReply = reply
            if let a = reply.analysis, !a.isEmpty {
                analysis = a
                print("🧠 R\(round) [\(a.mode)] \(a.primary)｜\(a.hypothesis)")
                print("   信心 \(a.confidence)｜能量 \(a.energy)｜拆分 \(a.splitRelevance)｜可收束 \(a.readyToClose)")
                print("   給過 \(a.tried)"
                      + (a.effectiveMethods.isEmpty ? "" : "｜過去有效 \(a.effectiveMethods)")
                      + (a.avoidRecommending.isEmpty ? "" : "｜避免 \(a.avoidRecommending)"))
            }
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
        // 保險：沒有實際互動就不留記錄也不發獎勵（避免「開了就有羊毛」的漏洞）
        guard hasRealConversation else { dismiss(); return }
        Task {
            isLoading = true
            var summary: String
            do { summary = try await AIService.shared.summarize(messages: thread, analysis: analysis) }
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
