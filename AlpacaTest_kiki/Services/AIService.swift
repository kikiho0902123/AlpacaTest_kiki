//
//  AIService.swift
//  AlpacaTest_kiki
//
//  AI track interface (TEAM_PLAN §1.5). Owned by C.
//  A and B touch AI ONLY through this interface.
//  Phase 1: mock only (useMock = true). Real API + PromptBuilder/ScoringEngine come later.
//

import Foundation

struct StuckReply {
    var text: String                     // AI message
    var quickOptions: [String]           // light options ("close" / "partly" / …)
    var recommendSplit: Bool             // STK-02F: true only when conditions are met
    var isClosing: Bool                  // Round 5+ closure tone
}

struct HistoricalTaskSummary: Codable {
    var name: String
    var category: String?
    var daysAgo: Int
    var hadStuckHelp: Bool
    var completionNote: String?
    var score: Int
}

final class AIService {
    static let shared = AIService()
    var useMock = true                   // stays true until real API works; also the offline demo mode

    private init() {}

    /// Stuck-help chat. `round` computed by the caller (user messages in the session).
    /// Round 8: the caller disables input (STK-02H); safety triggers are exempt from the 8-round cap.
    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String) async throws -> StuckReply {
        if useMock { return Self.mockStuckReply(round: round) }
        // TODO(C, Phase 4): real URLSession call via PromptBuilder + JSON decode into StuckReply.
        return Self.mockStuckReply(round: round)
    }

    /// Split suggestion: 2–5 subtask names (SPL-01).
    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?) async throws -> [String] {
        if useMock {
            return ["先花 10 分鐘列出大綱", "完成第一小段", "檢查並收尾"]
        }
        // TODO(C, Phase 4): real call.
        return ["先花 10 分鐘列出大綱", "完成第一小段", "檢查並收尾"]
    }

    /// Non-editable summary on exit (STK-04).
    func summarize(messages: [ChatMessage]) async throws -> String {
        if useMock {
            return "我們一起把卡住的地方拆成了更小的步驟。你已經想清楚下一步該做什麼了，慢慢來就好。"
        }
        // TODO(C, Phase 4): real call.
        return "（摘要）"
    }

    // MARK: - Mock

    private static func mockStuckReply(round: Int) -> StuckReply {
        switch round {
        case 0, 1:
            return StuckReply(
                text: "嘿，我在這裡陪你。可以先告訴我，現在是哪個部分讓你卡住了嗎？",
                quickOptions: ["不知道從哪開始", "覺得太難", "沒有動力", "時間不夠",
                               "被別的事打斷", "怕做不好", "太無聊", "還在想",
                               "需要別人幫忙", "其他"],
                recommendSplit: false,
                isClosing: false)
        case 2, 3, 4:
            return StuckReply(
                text: "聽起來這個任務對現在的你來說有點大。要不要我幫你把它拆成幾個小步驟？",
                quickOptions: ["說得對", "有一點", "不太是", "我想補充"],
                recommendSplit: true,
                isClosing: false)
        default: // round >= 5 → closure tone
            return StuckReply(
                text: "今天先聊到這裡，你已經很棒了。挑一個最小的下一步，先動起來就好。",
                quickOptions: [],
                recommendSplit: false,
                isClosing: true)
        }
    }
}
