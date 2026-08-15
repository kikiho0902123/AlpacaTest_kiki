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

/// Context Analysis：AI 每輪的內部分析。**永遠不顯示給使用者**。
/// 存在聊天 session 的 @State 裡（不進資料庫），下一輪當 PREVIOUS_ANALYSIS 回餵，
/// 讓 AI 能沿用／推翻自己上一輪的假設，而不是每輪從零重推。
/// 也餵給拆分與摘要，讓它們知道「當時到底卡在哪」而不用重讀整段對話。
struct ContextAnalysis: Codable, Equatable {
    /// 觀察到的卡點，最多 3 個
    var blockers: [String] = []
    /// blockers 中現在最值得介入的那一個
    var primary: String = ""
    /// 一句話的 Working Hypothesis，可被使用者推翻
    var hypothesis: String = ""
    /// low / medium / high — 決定 text 要用暫時性語氣還是直接給行動
    var confidence: String = "low"
    /// low / medium / high — 決定建議的負擔上限
    var energy: String = "medium"
    /// 已經給過的建議關鍵字，跨輪累積 → 下一輪不准重複推薦
    var tried: [String] = []

    /// 空分析不值得回餵（回餵空的只會浪費 token 又干擾模型）
    var isEmpty: Bool { primary.isEmpty && hypothesis.isEmpty && blockers.isEmpty }
}

extension ContextAnalysis {
    private enum CodingKeys: String, CodingKey {
        case blockers, primary, hypothesis, confidence, energy, tried
    }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockers   = (try? c.decodeIfPresent([String].self, forKey: .blockers)) ?? []
        primary    = (try? c.decodeIfPresent(String.self, forKey: .primary)) ?? ""
        hypothesis = (try? c.decodeIfPresent(String.self, forKey: .hypothesis)) ?? ""
        confidence = (try? c.decodeIfPresent(String.self, forKey: .confidence)) ?? "low"
        energy     = (try? c.decodeIfPresent(String.self, forKey: .energy)) ?? "medium"
        tried      = (try? c.decodeIfPresent([String].self, forKey: .tried)) ?? []
    }
}

struct StuckReply: Codable {
    var text: String                     // AI 訊息
    var quickOptions: [String] = []      // 輕量選項（很接近/有一部分對/…）
    var recommendSplit: Bool = false     // STK-02F：符合條件才 true
    var isClosing: Bool = false          // Round 5+ 收斂語氣
    var analysis: ContextAnalysis?       // 內部分析，不顯示（見 ContextAnalysis）
}

// AI 回的 JSON 欄位可能缺漏，缺的用預設值補，不讓整包 parse 失敗
extension StuckReply {
    private enum CodingKeys: String, CodingKey {
        case text, quickOptions, recommendSplit, isClosing, analysis
    }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        quickOptions = (try? c.decodeIfPresent([String].self, forKey: .quickOptions)) ?? []
        recommendSplit = (try? c.decodeIfPresent(Bool.self, forKey: .recommendSplit)) ?? false
        isClosing = (try? c.decodeIfPresent(Bool.self, forKey: .isClosing)) ?? false
        analysis = try? c.decodeIfPresent(ContextAnalysis.self, forKey: .analysis)
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
    /// var 而非 let：ModelCompareTests 要能在同一份 prompt 上橫向比較不同模型
    ///
    /// 為什麼是 gpt-5.5（ModelCompareTests 實測，同一份 prompt 同一段對話）：
    ///   gpt-5-mini   平均 4.5s／輪，R3 只會說「先寫三句事實」——還在教怎麼寫週報
    ///   gpt-5.4-mini 平均 2.1s／輪，但 R2 就違規下標題（prompt 規定 R1/R2 不用）
    ///   gpt-5.5      平均 2.3s／輪，R3 抓到真正的卡點是「怕被評價」，
    ///                給的是「開一份草稿，標不給主管版」——拿掉會被評價的前提
    /// 快一倍又更準，沒有理由留在舊模型。
    static var model = "gpt-5.5"
    /// var 而非 let：測試要能指向壞掉的位址驗證降級行為
    static var endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// gpt-5 系列的思考量。minimal ＝幾乎不思考，會忽略 prompt 裡的字數自我檢查，
    /// 實測話變超長又抓不到重點；low 慢約 1–2 秒但守規則，聊天室用這個。
    static let reasoningEffort = "low"
    /// gpt-5 系列的話多程度（low/medium/high）。聊天泡泡固定 low，
    /// 這是「字數」最直接的旋鈕，比 prompt 裡寫「100 字」有效得多。
    static let chatVerbosity = "low"
    /// 「不需要思考」那檔的名字會隨模型世代改：gpt-5.0 家族叫 minimal，
    /// 5.1 之後改名叫 none，送錯的那個會直接 400（不是降級，是整包失敗）。
    /// R1 開場用得到這檔。
    static var lowestEffort: String {
        let legacyFamily = model == "gpt-5" || model.hasPrefix("gpt-5-")
        return legacyFamily ? "minimal" : "none"
    }

    /// 低延遲服務層（已實測本帳號可用）。單價較高但 demo 用量可忽略，換聊天不卡頓。
    /// 若帳號被降級或改用其他 model 而收到 400，把這行改成 nil 就會退回一般排隊。
    static let serviceTier: String? = "priority"
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
    /// 有 key 就走真 API（已驗證 gpt-5.5 可用），沒 key 自動走離線罐頭。
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
    /// previous：上一輪的 Context Analysis。有給就回餵，AI 會判斷假設還成不成立。
    /// 預設 nil 保持舊呼叫方式可用（契約 §5 相容）。
    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String,
                   previous: ContextAnalysis? = nil) async throws -> StuckReply {

        // 安全層：最後一句使用者訊息命中關鍵詞 → 不打 API，回固定關懷訊息
        if let last = messages.last(where: { $0.role == "user" }),
           SafetyGate.isTriggered(last.content) {
            return SafetyGate.reply
        }

        if useMock { return Self.mockStuckReply(round: round, task: task) }

        var apiMessages: [[String: String]] = [
            ["role": "system",
             "content": PromptBuilder.stuckSystem(task: task, round: round,
                                                  history: history, profileJSON: profileJSON,
                                                  previous: previous)]
        ]
        if messages.isEmpty {
            apiMessages.append(["role": "user", "content": "（使用者剛進入聊天室，請依 Round 1 指令開場）"])
        } else {
            apiMessages += messages.map { ["role": $0.role, "content": $0.content] }
        }

        do {
            // R1 只是打招呼：沒有使用者訊息可分析，不需要思考預算，用 minimal 換開場速度
            let raw = try await callChat(apiMessages, wantJSON: true,
                                         effort: round <= 1 ? AIConfig.lowestEffort : AIConfig.reasoningEffort)
            var reply = Self.decodeStuckReply(raw)
            // tried 是防重複推薦的關鍵，不能讓模型「忘記」把上一輪的帶過來 → 程式面合併
            reply.analysis = Self.carryForward(previous, into: reply.analysis)
            return reply
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "卡關聊天")
            return Self.mockStuckReply(round: round, task: task)
        }
    }

    /// 拆分建議：2–5 個子任務名稱（SPL-01）
    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?,
                      analysis: ContextAnalysis? = nil) async throws -> [String] {
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
        if let a = analysis, !a.isEmpty {
            user += "\n\n這次卡關的判讀（來自對話分析，拆分請直接針對它）："
            user += "\n主要阻力：\(a.primary)"
            if !a.hypothesis.isEmpty { user += "\n判斷：\(a.hypothesis)" }
            if a.energy == "low" { user += "\n注意：使用者目前能量偏低，第一個子任務要特別小。" }
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
    func summarize(messages: [ChatMessage], analysis: ContextAnalysis? = nil) async throws -> String {
        if useMock {
            try? await Task.sleep(nanoseconds: 400_000_000)
            return "今天聊到你在這個任務上的卡點，主要是不知道從哪裡開始。我們一起找到了一個可以先動手的小步驟。累了就休息，明天再繼續就好。"
        }
        var transcript = messages
            .map { "\($0.role == "user" ? "使用者" : "AI")：\($0.content)" }
            .joined(separator: "\n")
        // 摘要要寫「當時為什麼卡住」——直接給判讀，比讓它重讀對話重猜一次準
        if let a = analysis, !a.isEmpty {
            transcript += "\n\n（系統判讀，供你寫『為什麼卡住』時參考，不要照抄術語）"
            transcript += "\n主要阻力：\(a.primary)"
            if !a.hypothesis.isEmpty { transcript += "\n判斷：\(a.hypothesis)" }
        }
        do {
            let raw = try await callChat([
                ["role": "system", "content": PromptBuilder.summarySystem()],
                ["role": "user", "content": transcript]
            ], wantJSON: false, verbosity: "medium")   // 摘要要 100–150 字，low 會太短
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "對話摘要")
            return "今天聊到你在這個任務上的卡點，主要是不知道從哪裡開始。我們一起找到了一個可以先動手的小步驟。累了就休息，明天再繼續就好。"
        }
    }

    // MARK: - OpenAI 呼叫（含 429/5xx 退避重試 ×2：1s/3s）

    private func callChat(_ messages: [[String: String]], wantJSON: Bool,
                          verbosity: String = AIConfig.chatVerbosity,
                          effort: String = AIConfig.reasoningEffort) async throws -> String {
        let key = Secrets.openAIKey
        guard !key.isEmpty else { throw AIServiceError.missingKey }

        var body: [String: Any] = ["model": AIConfig.model, "messages": messages]
        if wantJSON { body["response_format"] = ["type": "json_object"] }
        // gpt-5 系列是 reasoning 模型：不送 temperature/max_tokens（會被拒），
        // 改用 reasoning_effort 控思考量、verbosity 控話長度
        if AIConfig.model.hasPrefix("gpt-5") {
            body["reasoning_effort"] = effort
            body["verbosity"] = verbosity
        }
        if let tier = AIConfig.serviceTier { body["service_tier"] = tier }

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
           var reply = try? JSONDecoder().decode(StuckReply.self, from: data) {
            reply.text = trimForBubble(reply.text)
            return reply
        }
        return StuckReply(text: trimForBubble(raw))
    }

    /// 合併上一輪與這一輪的分析：`tried` 取聯集（不能因為模型漏抄就忘記給過什麼），
    /// 其餘欄位以新的為準——假設本來就該被推翻，新的空值代表模型沒重填，才沿用舊的。
    nonisolated static func carryForward(_ previous: ContextAnalysis?,
                                         into current: ContextAnalysis?) -> ContextAnalysis? {
        guard let previous, !previous.isEmpty else { return current }
        guard var merged = current else { return previous }

        var tried = previous.tried
        for item in merged.tried where !tried.contains(item) { tried.append(item) }
        merged.tried = tried

        if merged.primary.isEmpty    { merged.primary = previous.primary }
        if merged.hypothesis.isEmpty { merged.hypothesis = previous.hypothesis }
        if merged.blockers.isEmpty   { merged.blockers = previous.blockers }
        return merged
    }

    /// 字數保險絲：prompt 和 verbosity 都失手時的最後一道。
    /// 只在超過 150 字才動手，而且切在句尾（。！？換行），不會把句子砍一半。
    /// 保留前 3 句 —— 開頭通常是理解與 Insight，尾巴才是離題的補充。
    nonisolated static func trimForBubble(_ text: String, limit: Int = 150) -> String {
        guard text.count > limit else { return text }
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "。！？!?\n".contains(ch) {
                sentences.append(current)
                current = ""
            }
        }
        if !current.isEmpty { sentences.append(current) }
        guard sentences.count > 1 else { return String(text.prefix(limit)) + "…" }

        var result = ""
        for s in sentences.prefix(3) {
            if result.count + s.count > limit && !result.isEmpty { break }
            result += s
        }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(text.prefix(limit)) + "…" : trimmed
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
