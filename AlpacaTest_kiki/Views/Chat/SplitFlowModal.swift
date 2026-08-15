//
//  SplitFlowModal.swift
//  [C 擁有 — 明天複製到 repo 的 Views/Chat/SplitFlowModal.swift]
//
//  SPL-01~04 拆分全流程，三入口共用：
//    .startAsk（TOD-04 選「是，我要拆分」）/ .manual（任務卡「拆分」）/ .fromChat（卡關聊天推薦）
//  進場呼叫 suggestSplit → 母任務卡＋2~5 張可編輯子任務 → SPL-03 確認 → 建子任務
//  （parentID、繼承分類）、母任務 status="split"、grant(.acceptSplit)、post .taskSplit
//  → SPL-04 完成（文案依 source 分兩種）→ dismiss + onFinished()
//  呼叫方式：.sheet { SplitFlowModal(task: task, source: .manual) }
//

import SwiftUI
import SwiftData

enum SplitSource {
    case startAsk, manual, fromChat
}

struct SplitFlowModal: View {
    let task: TodoTask
    let source: SplitSource
    var chatContext: [ChatMessage]? = nil
    /// 從卡關聊天進來時帶入的內部判讀，讓拆分直接針對卡點（見 ContextAnalysis）
    var analysis: ContextAnalysis? = nil
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// onAppear 會重複觸發，用旗標確保只打一次 API
    @State private var didLoad = false

    private struct Row: Identifiable {
        let id = UUID()
        var text: String
    }

    @State private var rows: [Row] = []
    @State private var isLoading = true
    @State private var showConfirm = false
    @State private var doneCount: Int?                   // 非 nil → SPL-04

    private var validNames: [String] {
        rows.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ChatTheme.cream.ignoresSafeArea()
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("AI 正在幫你拆分…").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    editor
                }
            }
            .navigationTitle("拆分任務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        // 不能用 .task {}：sheet 彈出時會重建 view 而取消請求（URLError.cancelled），
        // 結果整個拆分流程都退化成罐頭子任務。改用不綁 view 生命週期的 Task {}。
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            Task { await loadSuggestions() }
        }
        .overlay {
            if showConfirm {
                DimmedModal {
                    ConfirmModal(
                        title: "確定要拆分任務嗎？",
                        message: "「\(task.name)」會拆成 \(validNames.count) 個子任務，母任務將移至「已拆分」。",
                        primary: ModalAction(title: "確認拆分") { showConfirm = false; performSplit() },
                        secondary: ModalAction(title: "取消") { showConfirm = false }
                    )
                }
            }
            if let n = doneCount {
                DimmedModal {
                    ConfirmModal(
                        title: "拆分完成",
                        message: source == .fromChat
                            ? "已建立 \(n) 個子任務。回到聊天室，我們把這次對話做個記錄。"
                            : "已建立 \(n) 個子任務，母任務移至「已拆分」。一次一小步就好！",
                        primary: ModalAction(title: "確定") { dismiss(); onFinished?() }
                    )
                }
            }
        }
    }

    // MARK: - 母任務卡 + 可編輯子任務列表

    private var editor: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.name).font(.headline).foregroundStyle(ChatTheme.brown)
                            if let cat = task.category {
                                Text("\(cat)\(task.subcategory.map { "／\($0)" } ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(ChatTheme.terracotta)
                    }
                } header: {
                    Text("母任務")
                }

                Section {
                    ForEach($rows) { $row in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundStyle(ChatTheme.terracotta.opacity(0.6))
                            TextField("子任務名稱", text: $row.text)
                            Button {
                                rows.removeAll { $0.id == row.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if rows.count < 5 {
                        Button {
                            rows.append(Row(text: ""))
                        } label: {
                            Label("新增子任務", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                        .tint(ChatTheme.terracotta)
                    }
                } header: {
                    Text("子任務（2–5 個，可改名／刪除／新增）")
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                showConfirm = true
            } label: {
                Text("確認拆分")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(ChatTheme.terracotta)
            .disabled(validNames.count < 2)
            .padding()
        }
    }

    // MARK: - 動作

    private func loadSuggestions() async {
        do {
            let names = try await AIService.shared.suggestSplit(task: task, chatContext: chatContext, analysis: analysis)
            rows = names.map { Row(text: $0) }
        } catch {
            rows = [Row(text: "把「\(task.name)」列出具體步驟"),
                    Row(text: "先做最小的第一步（10 分鐘）")]
        }
        isLoading = false
    }

    private func performSplit() {
        for (index, name) in validNames.prefix(5).enumerated() {
            let child = TodoTask(name: name)
            child.parentID = task.id                     // 繫回母任務
            child.category = task.category               // 繼承分類
            child.subcategory = task.subcategory
            child.colorHex = task.colorHex
            child.startDate = task.startDate
            child.isUrgent = task.isUrgent
            child.sortOrder = index
            modelContext.insert(child)
        }
        task.status = "split"                            // SPL-05 母任務 read-only 由 A 的卡片處理
        modelContext.insert(TaskLog(taskID: task.id, type: "split",
                                    content: "拆分為：" + validNames.joined(separator: "、")))
        RewardEngine.grant(.acceptSplit, context: modelContext)
        try? modelContext.save()
        NotificationCenter.default.post(name: .taskSplit, object: task.id)
        doneCount = validNames.count                     // → SPL-04
    }
}
