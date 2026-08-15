//
//  AIService.swift
//  [C 擁有 — 明天複製到 repo 的 Services/AIService.swift]
//
//  介面完全依 TEAM_PLAN v2 契約 §5。A/B 只透過這個 class 碰 AI。
//  useMock = true 時完全離線（也是現場網路掛掉的 demo 模式）。
//  串真 API 前先跑 C_Line/apitest.swift 確認 key 與模型，再把 useMock 改 false。
//

import Foundation
import SwiftData

// MARK: - 契約定義的回傳型別

struct StuckReply: Codable {
    var text: String                     // AI 訊息
    var quickOptions: [String] = []      // 輕量選項（很接近/有一部分對/…）
    var recommendSplit: Bool = false     // STK-02F：符合條件才 true
    var isClosing: Bool = false          // Round 5+ 收斂語氣
}

// AI 回的 JSON 欄位可能缺漏，缺的用預設值補，不讓整包 parse 失敗
extension StuckReply {
    private enum CodingKeys: String, CodingKey { case text, quickOptions, recommendSplit, isClosing }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        quickOptions = (try? c.decodeIfPresent([String].self, forKey: .quickOptions)) ?? []
        recommendSplit = (try? c.decodeIfPresent(Bool.self, forKey: .recommendSplit)) ?? false
        isClosing = (try? c.decodeIfPresent(Bool.self, forKey: .isClosing)) ?? false
    }
}

struct HistoricalTaskSummary: Codable {
    var name: String
    var category: String?
    var daysAgo: Int
    var hadStuckHelp: Bool
    var completionNote: String?
    var score: Int
}

// MARK: - 設定

enum AIConfig {
    /// 先跑 apitest.swift 確認你的帳號有哪個模型，再改這裡（改原始碼重 build，不做執行期切換）
    static let model = "gpt-5-mini"
    /// var 而非 let：測試要能指向壞掉的位址驗證降級行為
    static var endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
}

enum AIServiceError: LocalizedError {
    case missingKey
    case badStatus(Int, String)
    case emptyReply
    var errorDescription: String? {
        switch self {
        case .missingKey: "還沒設定 API key（Secrets.swift）"
        case .badStatus(let code, let body): "API 回應 \(code)：\(body.prefix(200))"
        case .emptyReply: "API 回了空內容"
        }
    }
}

// MARK: - 安全層（Batch 2 必做，先內建：命中就不打 API）

enum SafetyGate {
    static let keywords = ["自殺", "自傷", "想死", "不想活", "輕生", "結束生命", "傷害自己", "活不下去", "了結自己"]
    static func isTriggered(_ text: String) -> Bool {
        keywords.contains { text.contains($0) }
    }
    static let reply = StuckReply(
        text: "謝謝你願意說出來，這聽起來真的很辛苦。任務的事可以先放一邊——你現在的感受更重要。如果你有傷害自己的念頭，請撥打安心專線 1925（24 小時、免費），或找一位你信任的人聊聊。你不需要一個人撐著，我也會在這裡陪你。",
        quickOptions: [], recommendSplit: false, isClosing: false)
}

// MARK: - AIService

@MainActor
final class AIService {
    static let shared = AIService()
    /// 有 key 就走真 API（已驗證 gpt-5-mini 可用），沒 key 自動走離線罐頭。
    /// 這樣 A/B 不用設定就能開發，C 和 demo 機器則自動接真 AI。
    /// 現場網路掛掉時：手動設成 true 即可完整離線 demo。
    var useMock = Secrets.openAIKey.isEmpty

    /// Demo 保命：真 API 掛掉（斷網／429／key 失效）時，不把錯誤丟到使用者面前，
    /// 直接改用罐頭回應讓流程走完。開發時看 console 的 ⚠️ 就知道有降級。
    /// 設成 false 可讓錯誤照常拋出（想除錯 API 問題時用）。
    var fallbackToMockOnFailure = true

    private func degrade(_ error: Error, _ what: String) {
        print("⚠️ AI \(what) 失敗，改用罐頭回應：\(error.localizedDescription)")
    }

    /// 卡關聊天。round 由呼叫端算（該 session 的 user 訊息數 + 1；R1 = AI 開場）
    /// Round 8：呼叫端鎖輸入（STK-02H）；safety 觸發不受 8 輪限制
    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String) async throws -> StuckReply {

        // 安全層：最後一句使用者訊息命中關鍵詞 → 不打 API，回固定關懷訊息
        if let last = messages.last(where: { $0.role == "user" }),
           SafetyGate.isTriggered(last.content) {
            return SafetyGate.reply
        }

        if useMock { return Self.mockStuckReply(round: round, task: task) }

        var apiMessages: [[String: String]] = [
            ["role": "system",
             "content": PromptBuilder.stuckSystem(task: task, round: round,
                                                  history: history, profileJSON: profileJSON)]
        ]
        if messages.isEmpty {
            apiMessages.append(["role": "user", "content": "（使用者剛進入聊天室，請依 Round 1 指令開場）"])
        } else {
            apiMessages += messages.map { ["role": $0.role, "content": $0.content] }
        }

        do {
            let raw = try await callChat(apiMessages, wantJSON: true)
            return Self.decodeStuckReply(raw)
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "卡關聊天")
            return Self.mockStuckReply(round: round, task: task)
        }
    }

    /// 拆分建議：2–5 個子任務名稱（SPL-01）
    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?) async throws -> [String] {
        if useMock {
            try? await Task.sleep(nanoseconds: 500_000_000)
            return ["列出\(task.name)的三個小步驟", "先做 10 分鐘暖身", "完成第一個小段落"]
        }
        var user = "任務名稱：\(task.name)\n複雜度：\(["易","中","難"][max(0, min(task.complexity, 2))])"
        if let cat = task.category { user += "\n分類：\(cat)" }
        if let note = task.note, !note.isEmpty { user += "\n備註：\(note)" }
        if let chat = chatContext, !chat.isEmpty {
            let transcript = chat.suffix(12)
                .map { "\($0.role == "user" ? "使用者" : "AI")：\($0.content)" }
                .joined(separator: "\n")
            user += "\n\n以下是使用者剛才的卡關對話，拆分要對症下藥：\n\(transcript)"
        }
        do {
            let raw = try await callChat([
                ["role": "system", "content": PromptBuilder.splitSystem()],
                ["role": "user", "content": user]
            ], wantJSON: true)
            let names = Self.decodeSubtasks(raw)
            guard names.count >= 2 else {
                return ["把「\(task.name)」列出具體步驟", "先做最小的第一步（10 分鐘）"]
            }
            return Array(names.prefix(5))
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "拆分建議")
            return ["列出\(task.name)的三個小步驟", "先做 10 分鐘暖身", "完成第一個小段落"]
        }
    }

    /// 離開時的不可編輯 Summary（STK-04）
    func summarize(messages: [ChatMessage]) async throws -> String {
        if useMock {
            try? await Task.sleep(nanoseconds: 400_000_000)
            return "今天聊到你在這個任務上的卡點，主要是不知道從哪裡開始。我們一起找到了一個可以先動手的小步驟。累了就休息，明天再繼續就好。"
        }
        let transcript = messages
            .map { "\($0.role == "user" ? "使用者" : "AI")：\($0.content)" }
            .joined(separator: "\n")
        do {
            let raw = try await callChat([
                ["role": "system", "content": PromptBuilder.summarySystem()],
                ["role": "user", "content": transcript]
            ], wantJSON: false)
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "對話摘要")
            return "今天聊到你在這個任務上的卡點，主要是不知道從哪裡開始。我們一起找到了一個可以先動手的小步驟。累了就休息，明天再繼續就好。"
        }
    }

    // MARK: - OpenAI 呼叫（含 429/5xx 退避重試 ×2：1s/3s）

    private func callChat(_ messages: [[String: String]], wantJSON: Bool) async throws -> String {
        let key = Secrets.openAIKey
        guard !key.isEmpty else { throw AIServiceError.missingKey }

        var body: [String: Any] = ["model": AIConfig.model, "messages": messages]
        if wantJSON { body["response_format"] = ["type": "json_object"] }
        // gpt-5 系列是 reasoning 模型：不送 temperature/max_tokens（會被拒），
        // 用 reasoning_effort=minimal 換取聊天所需的低延遲
        if AIConfig.model.hasPrefix("gpt-5") { body["reasoning_effort"] = "minimal" }

        var req = URLRequest(url: AIConfig.endpoint, timeoutInterval: 45)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let delaysNs: [UInt64] = [0, 1_000_000_000, 3_000_000_000]
        var lastError: Error = AIServiceError.emptyReply

        for delay in delaysNs {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if status == 429 || status >= 500 {
                    lastError = AIServiceError.badStatus(status, String(data: data, encoding: .utf8) ?? "")
                    continue                                  // 退避重試
                }
                guard (200..<300).contains(status) else {
                    throw AIServiceError.badStatus(status, String(data: data, encoding: .utf8) ?? "")
                }
                guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = obj["choices"] as? [[String: Any]],
                      let msg = choices.first?["message"] as? [String: Any],
                      let content = msg["content"] as? String, !content.isEmpty else {
                    throw AIServiceError.emptyReply
                }
                print("🟢 AI raw response:\n\(content)")       // 除錯守則：parse 前先 print
                return content
            } catch let e as URLError {
                lastError = e                                 // 斷網/逾時也重試
                continue
            }
        }
        throw lastError
    }

    // MARK: - Parse（失敗 fallback 全文塞 text，永不 crash）

    nonisolated static func decodeStuckReply(_ raw: String) -> StuckReply {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = cleaned.data(using: .utf8),
           let reply = try? JSONDecoder().decode(StuckReply.self, from: data) {
            return reply
        }
        return StuckReply(text: raw)
    }

    nonisolated static func decodeSubtasks(_ raw: String) -> [String] {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let dict = obj as? [String: Any], let arr = dict["subtasks"] as? [String] { return arr }
        if let arr = obj as? [String] { return arr }
        return []
    }

    // MARK: - Mock（round 對應 STK-02A~H 的罐頭劇本）

    nonisolated static func mockStuckReply(round: Int, task: TodoTask) -> StuckReply {
        switch round {
        case 1:
            // 開場語出自設計師 03｜Round 1 建議語氣
            return StuckReply(text: "嗨，很高興你願意停下來找幫手。跟我說說，現在是什麼讓你在「\(task.name)」卡住？你可以直接點下面比較接近的狀況，也可以自己打字補充。")
        case 2:
            return StuckReply(
                text: "聽起來，比起任務本身太難，更像是「不知道從哪裡開始」讓你動不了——我猜中了嗎?",
                quickOptions: ["很接近", "有一部分對", "不太是這樣", "我想補充"])
        case 3:
            return StuckReply(
                text: "我理解了。這種時候最有用的通常不是逼自己更努力，而是把門檻降到低得不可思議——低到「做了也不算什麼」的程度，反而就能開始。你想要我直接給你一個下一步，還是想再聊聊？",
                quickOptions: ["給我下一步", "我想再聊聊"],
                recommendSplit: task.complexity >= 1)
        case 4:
            return StuckReply(text: "好，那我們再往下挖一點。你上次順利開始做類似的事情，是什麼情況？那時候有什麼不一樣？")
        case 5, 6, 7:
            return StuckReply(
                text: "我們聊了不少，幫你整理一下：卡點主要是起步門檻，而你其實已經知道第一步可以是什麼了。接下來就先做那 10 分鐘，做完就算贏。還有什麼想補充的嗎？",
                isClosing: true)
        default:
            return StuckReply(
                text: "今天聊到這裡吧。最值得帶走的一步：把任務縮小到 10 分鐘就能完成的版本，現在就去做那一小塊。你已經比剛進來的時候清楚多了。我先休息一下，15 分鐘後如果還需要我，隨時回來。🌿",
                isClosing: true)
        }
    }
}
