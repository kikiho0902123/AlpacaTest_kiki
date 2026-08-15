//
//  AITaskCreationView.swift
//  AlpacaTest_kiki
//
//  用一段自然語言描述建立任務。Owned by A。
//  解析交給 C 的 AIService.parseTasks(_:)；這裡只負責輸入、載入中、失敗重試。
//
//  ★ AI 不會自己建立任務 ★
//  解析結果一律先丟進批次確認頁，按下「建立任務」才一次寫進資料庫。
//

import SwiftUI
import SwiftData

struct AITaskCreationView: View {
    @Environment(\.dismiss) private var dismiss

    /// 使用者輸入的描述。失敗時絕對不清掉。
    @State private var input = ""
    @State private var phase: Phase = .editing
    @State private var batchDraft: BatchDraft?
    @State private var manualDraft: ManualDraft?

    private enum Phase: Equatable {
        case editing
        case parsing
        case failed(String)
    }

    /// sheet(item:) 需要 Identifiable，包一層避免動到 C 的型別
    private struct BatchDraft: Identifiable {
        let id = UUID()
        let tasks: [ParsedTask]
    }

    private struct ManualDraft: Identifiable {
        let id = UUID()
        let parsed: ParsedTask
    }

    private var isParsing: Bool { phase == .parsing }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.alpacaCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("用一段話描述你想做的事，AI 會幫你整理成一個或多個任務。")
                            .font(.alpacaBody)
                            .foregroundStyle(Color.alpacaBrown.opacity(0.8))

                        inputField

                        if case .failed(let message) = phase {
                            failureBlock(message: message)
                        }

                        generateButton

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("AI 幫你建立")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isParsing)
                }
            }
        }
        // 解析成功 → 顯示批次清單，使用者確認後才一次建立
        .sheet(item: $batchDraft) { box in
            ParsedTaskBatchView(tasks: box.tasks) {
                dismiss()
            }
        }
        .sheet(item: $manualDraft) { box in
            TaskEditorView(prefill: box.parsed) {
                dismiss()
            }
        }
    }

    // MARK: - Pieces

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("任務描述")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Color.alpacaBrown.opacity(0.75))

            TextField("例如：明天買菜，下週三交經濟學報告",
                      text: $input,
                      axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                        .fill(.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                        .stroke(Color.alpacaBeige, lineWidth: 1.2)
                )
                .disabled(isParsing)          // 解析中不給改，但文字照樣看得到
                .opacity(isParsing ? 0.6 : 1)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await parse() }
        } label: {
            HStack(spacing: 10) {
                if isParsing {
                    ProgressView()
                        .tint(Color.alpacaBrown)
                    Text("AI 正在整理…")
                } else {
                    Image(systemName: "sparkles")
                    Text("產生")
                }
            }
            .font(.alpacaHeading)
            .foregroundStyle(Color.alpacaBrown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary.opacity(isParsing ? 0.5 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isParsing || trimmedInput.isEmpty)
    }

    /// 失敗：講清楚原因，保留輸入，給重試和改用手動兩條路
    private func failureBlock(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.alpacaStuck)

                Text(message)
                    .font(.alpacaBody)
                    .foregroundStyle(Color.alpacaBrown)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await parse() }
                } label: {
                    Label("重試", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.alpacaBrown)

                Button {
                    // 改用手動：把打過的字帶成備註，不要讓它白打
                    manualDraft = ManualDraft(parsed: ParsedTask(name: "", note: trimmedInput))
                } label: {
                    Label("改用手動建立", systemImage: "square.and.pencil")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.alpacaBrown)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(Color.alpacaStuck.opacity(0.12))
        )
    }

    // MARK: - Parsing

    private func parse() async {
        let text = trimmedInput
        guard !text.isEmpty else { return }

        phase = .parsing
        do {
            let parsed = try await AIService.shared.parseTasks(text)
            phase = .editing
            batchDraft = BatchDraft(tasks: parsed)
        } catch {
            // 輸入完整保留，使用者可以直接重試或改手動
            phase = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    AITaskCreationView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
