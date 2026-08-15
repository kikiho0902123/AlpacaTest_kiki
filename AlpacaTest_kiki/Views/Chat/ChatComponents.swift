//
//  ChatComponents.swift
//  [C 擁有 — 明天複製到 repo 的 Views/Chat/ChatComponents.swift]
//
//  聊天室的積木：Bubble、R1 卡點 Chips、輕量選項、Summary Modal、
//  STK-01 確認包裝（給 A 呼叫）。介面規格見 INTERFACES.md。
//

import SwiftUI

// MARK: - R1 卡點 Chips（STK-02A）

enum StuckChips {
    /// 預設 10 顆。要加/改選項直接編輯這個陣列。
    static var defaults: [String] = [
        "不知道從哪開始", "任務太大了", "一直分心", "覺得好累", "怕做不好",
        "沒有動力", "時間不夠", "卡在某個步驟", "很焦慮", "提不起勁",
    ]
    /// AI 若在 R1 回了自己的 chips 就用 AI 的，否則用預設（兩條路都通）
    static func resolve(aiProvided: [String]) -> [String] {
        aiProvided.isEmpty ? defaults : Array(aiProvided.prefix(10))
    }
}

// MARK: - 聊天室配色（C 私有，不依賴 A 的 Theme；整合後可換成 Theme 的色票）

enum ChatTheme {
    static let cream      = Color(red: 0.98, green: 0.93, blue: 0.85)
    static let terracotta = Color(red: 0.85, green: 0.45, blue: 0.28)
    static let brown      = Color(red: 0.45, green: 0.32, blue: 0.22)
    static let aiBubble   = Color.white
    static let userBubble = Color(red: 0.93, green: 0.58, blue: 0.30).opacity(0.25)
}

// MARK: - 輕量 Markdown 渲染

/// SwiftUI 的 Text 只有「字面值」會被當 Markdown 解析，變數不會；
/// 而且就算解析了也只支援行內樣式（粗體／斜體／連結），沒有項目符號和換行階層。
/// 所以這裡自己拆行：`- ` 開頭畫成有縮排的項目，其餘走行內 Markdown。
/// 支援範圍刻意很窄（換行、`- `、`**粗體**`）——跟 PromptBuilder 允許 AI 用的排版一致。
struct MarkdownText: View {
    let raw: String

    private enum Block: Identifiable {
        case heading(String)
        case paragraph(String)
        case bullet(String)
        var id: String {
            switch self {
            case .heading(let s):   return "h\(s)"
            case .paragraph(let s): return "p\(s)"
            case .bullet(let s):    return "b\(s)"
            }
        }
    }

    private var blocks: [Block] {
        raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                // 長的先比，否則 "# " 會先吃掉 "### "
                for marker in ["#### ", "### ", "## ", "# "] where line.hasPrefix(marker) {
                    return .heading(String(line.dropFirst(marker.count)))
                }
                for marker in ["- ", "• ", "* "] where line.hasPrefix(marker) {
                    return .bullet(String(line.dropFirst(marker.count)))
                }
                // 整行都是粗體 → 模型其實是想下標題，當標題處理
                if line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4,
                   !line.dropFirst(2).dropLast(2).contains("**") {
                    return .heading(String(line.dropFirst(2).dropLast(2)))
                }
                return .paragraph(line)
            }
    }

    /// 行內樣式。inlineOnlyPreservingWhitespace：只解析粗體之類，不吃掉空白排版。
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        ) ?? AttributedString(s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks) { block in
                switch block {
                case .heading(let s):
                    // 聊天泡泡裡的標題：靠字重和顏色做出層級，不要放大字級（會很吵）
                    Text(inline(s))
                        .fontWeight(.semibold)
                        .foregroundStyle(ChatTheme.terracotta)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                case .paragraph(let s):
                    Text(inline(s))
                        .fixedSize(horizontal: false, vertical: true)
                case .bullet(let s):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(ChatTheme.terracotta)
                        Text(inline(s))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 2)
                }
            }
        }
    }
}

// MARK: - 對話泡泡

struct ChatBubble: View {
    let role: String          // "user" / "assistant"
    let text: String

    var isUser: Bool { role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            MarkdownText(raw: text)
                .font(.subheadline)
                .foregroundStyle(ChatTheme.brown)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? ChatTheme.userBubble : ChatTheme.aiBubble)
                )
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct TypingBubble: View {
    var body: some View {
        HStack {
            ProgressView()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(ChatTheme.aiBubble))
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Chips 橫向滑動列（可多選帶入輸入框）

struct ChipsRow: View {
    let chips: [String]
    @Binding var inputText: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    let selected = inputText.contains(chip)
                    Button {
                        if selected {
                            inputText = inputText
                                .replacingOccurrences(of: chip + "、", with: "")
                                .replacingOccurrences(of: chip, with: "")
                        } else {
                            inputText += inputText.isEmpty ? chip : "、\(chip)"
                        }
                    } label: {
                        Text(chip)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(selected ? ChatTheme.terracotta : Color.white)
                            )
                            .foregroundStyle(selected ? .white : ChatTheme.brown)
                            .overlay(Capsule().stroke(ChatTheme.terracotta.opacity(0.4), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 輕量選項列（R2+：「很接近／有一部分對／…」，點了直接送出）

struct QuickOptionsRow: View {
    let options: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    Button(opt) { onTap(opt) }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(ChatTheme.terracotta)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Modal 背景（A 的 ConfirmModal 是純卡片，昏暗背景由呼叫端提供）

struct DimmedModal<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            content
        }
    }
}

// MARK: - STK-01 卡關確認（給 A 的包裝：換字版 ConfirmModal）

struct StuckConfirmModal: View {
    let onGo: () -> Void
    let onCancel: () -> Void

    var body: some View {
        DimmedModal {
            ConfirmModal(
                title: "卡住了嗎？",
                message: "讓 AI 幫你一把。聊聊現在是什麼卡住了你。",
                primary: ModalAction(title: "前往", action: onGo),
                secondary: ModalAction(title: "取消", action: onCancel)
            )
        }
    }
}

// MARK: - STK-04 Summary Modal（不可編輯＋有幫助/沒幫助）

struct SummaryModal: View {
    let text: String
    let onHelpful: () -> Void
    let onNotHelpful: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("對話記錄").font(.headline)
                ScrollView {
                    MarkdownText(raw: text)
                        .font(.subheadline)
                        .foregroundStyle(ChatTheme.brown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                Text("這段記錄會存進任務的 Task Record")
                    .font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("沒有幫助", action: onNotHelpful).buttonStyle(.bordered)
                    Button("對我有幫助", action: onHelpful).buttonStyle(.borderedProminent)
                        .tint(ChatTheme.terracotta)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .systemBackground)))
            .padding(32)
        }
    }
}

// MARK: - STK-05 沒幫助 Feedback

struct NoHelpFeedbackModal: View {
    @Binding var feedbackText: String
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("哪裡沒幫上忙？").font(.headline)
                Text("告訴我們原因，AI 會慢慢進步")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("例如：建議太籠統了…", text: $feedbackText, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("略過", action: onSkip).buttonStyle(.bordered)
                    Button("完成", action: onDone).buttonStyle(.borderedProminent)
                        .tint(ChatTheme.terracotta)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .systemBackground)))
            .padding(32)
        }
    }
}
