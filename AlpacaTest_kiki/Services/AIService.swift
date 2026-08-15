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

    // MARK: 設計師 §04 Routing —— 這些是「跨輪要記住」的狀態

    /// 目前的 Conversation Mode（§04 的 route）。**這是狀態，不是每輪重算的**：
    /// 使用者按了「給我下一步」進入 directNextStep 之後，之後每輪都該待在那個模式，
    /// 不能又飄回追問。空字串＝還沒決定。
    var mode: String = ""
    /// §02 Step 7：資訊是否不足以提供實際幫助
    var needClarification: Bool = false
    /// needClarification 為 true 時，那個唯一值得問的問題
    var clarificationQuestion: String = ""
    /// §02：拆分相關性是三值，不是布林。possible 不得主動推薦。
    /// recommended / possible / not_relevant
    var splitRelevance: String = "not_relevant"
    /// 拆分理由（內部用）
    var splitReason: String = ""
    /// §02 Step 4：過去對「這位使用者」真正有效的方法，最多 2 個。
    /// spec 明講這要優先於泛用 productivity tips。
    var effectiveMethods: [String] = []
    /// §02 Step 5：使用者明確表示不希望收到的方法，不得推薦
    var avoidRecommending: [String] = []
    /// §04：R5–7 已經得到足夠協助，不需要等到 R8 才收束
    var readyToClose: Bool = false

    /// 空分析不值得回餵（回餵空的只會浪費 token 又干擾模型）
    var isEmpty: Bool { primary.isEmpty && hypothesis.isEmpty && blockers.isEmpty }
}

/// §04 的 route 名稱。用字串而非 enum，因為模型填錯值時不該讓整包 parse 失敗。
enum ChatMode {
    static let clarification     = "clarification"
    static let initialAssistance = "initial_assistance"
    static let directNextStep    = "direct_next_step"
    static let deepConversation  = "deep_conversation"
    static let progressiveClosure = "progressive_closure"
    static let finalClosure      = "final_closure"

    /// 中文說明，注入 prompt 用
    static func label(_ mode: String) -> String {
        switch mode {
        case clarification:      return "clarification（還在釐清，只能問一個問題）"
        case initialAssistance:  return "initial_assistance（已開始提供實際協助）"
        case directNextStep:     return "direct_next_step（使用者要的是具體行動，不要再追問）"
        case deepConversation:   return "deep_conversation（使用者想再聊，但每輪都要推進）"
        case progressiveClosure: return "progressive_closure（開始收斂）"
        case finalClosure:       return "final_closure（最後一輪）"
        default:                 return mode
        }
    }
}

extension ContextAnalysis {
    private enum CodingKeys: String, CodingKey {
        case blockers, primary, hypothesis, confidence, energy, tried
        case mode, needClarification, clarificationQuestion
        case splitRelevance, splitReason, effectiveMethods, avoidRecommending, readyToClose
    }
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockers   = (try? c.decodeIfPresent([String].self, forKey: .blockers)) ?? []
        primary    = (try? c.decodeIfPresent(String.self, forKey: .primary)) ?? ""
        hypothesis = (try? c.decodeIfPresent(String.self, forKey: .hypothesis)) ?? ""
        confidence = (try? c.decodeIfPresent(String.self, forKey: .confidence)) ?? "low"
        energy     = (try? c.decodeIfPresent(String.self, forKey: .energy)) ?? "medium"
        tried      = (try? c.decodeIfPresent([String].self, forKey: .tried)) ?? []
        mode       = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? ""
        needClarification = (try? c.decodeIfPresent(Bool.self, forKey: .needClarification)) ?? false
        clarificationQuestion = (try? c.decodeIfPresent(String.self, forKey: .clarificationQuestion)) ?? ""
        splitRelevance = (try? c.decodeIfPresent(String.self, forKey: .splitRelevance)) ?? "not_relevant"
        splitReason    = (try? c.decodeIfPresent(String.self, forKey: .splitReason)) ?? ""
        effectiveMethods  = (try? c.decodeIfPresent([String].self, forKey: .effectiveMethods)) ?? []
        avoidRecommending = (try? c.decodeIfPresent([String].self, forKey: .avoidRecommending)) ?? []
        readyToClose = (try? c.decodeIfPresent(Bool.self, forKey: .readyToClose)) ?? false
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

/// 一週的原始素材（B 的回饋頁用）。刻意不吃 B 的 private WeeklyFeedbackData，
/// 而是吃 A 的 model 陣列 —— B 手上已經有這三包，呼叫時不用組任何東西。
///
/// 為什麼要 tasks：設計師規格的第一項分析是「本週較常卡關的任務**分類**」，
/// 而分類長在 TodoTask 上，TaskLog 只有 taskID。沒有 tasks 就分析不了分類。
struct WeeklyStats {
    var startDate: Date
    var endDate: Date
    var stats: [DailyStat]
    var logs: [TaskLog]
    var tasks: [TodoTask] = []

    var totalWool: Int  { stats.reduce(0) { $0 + $1.woolG } }
    var doneCount: Int  { stats.reduce(0) { $0 + $1.doneCount } }
    var startCount: Int { stats.reduce(0) { $0 + $1.startCount } }
    var stuckCount: Int { stats.reduce(0) { $0 + $1.stuckCount } }
    var closedDays: Int { stats.filter(\.isClosed).count }

    /// 這週完全沒有活動 —— 不值得叫 AI 生一段「你這週很棒」的空話，也不該花一次 API
    var isBarren: Bool { doneCount == 0 && startCount == 0 && stuckCount == 0 && logs.isEmpty }

    /// 餵給模型的素材。
    /// 數字與分類、時段都先在程式端算好：規格要求「不自行補充不存在的事實」，
    /// 讓模型自己從一堆時間戳推「他常在晚上卡住」很容易推錯。
    var digest: String {
        var s = "期間：\(Self.fmt(startDate)) – \(Self.fmt(endDate))\n"
        s += "完成 \(doneCount) 件｜開始 \(startCount) 件｜用了卡關解套 \(stuckCount) 次"
        s += "｜羊毛 \(totalWool)g｜有結算的天數 \(closedDays)/7\n"

        let daily = stats.sorted { $0.date < $1.date }.map {
            "\(Self.fmt($0.date))(\(Self.weekday($0.date)))：完成\($0.doneCount)、卡關\($0.stuckCount)、\($0.woolG)g"
        }
        if !daily.isEmpty { s += "逐日：\n" + daily.joined(separator: "\n") + "\n" }

        // 卡關集中在哪個分類／時段（規格第 1 項分析的素材）
        let stuckLogs = logs.filter { $0.type == "chatSummary" }
        if !stuckLogs.isEmpty {
            let byCategory = Dictionary(grouping: stuckLogs) { log in
                tasks.first { $0.id == log.taskID }?.category ?? "未分類"
            }.map { "\($0.key) \($0.value.count) 次" }.sorted()
            let bySlot = Dictionary(grouping: stuckLogs) { Self.slot($0.timestamp) }
                .map { "\($0.key) \($0.value.count) 次" }.sorted()
            s += "\n卡關發生在哪些分類：\(byCategory.joined(separator: "、"))\n"
            s += "卡關發生在哪些時段：\(bySlot.joined(separator: "、"))\n"
            s += "（注意：次數 1 的項目是單一事件，不得稱為「模式」）\n"
        }

        let notes = logs.filter { $0.type == "completion" }.map(\.content).filter { !$0.isEmpty }
        if !notes.isEmpty {
            s += "\n他完成任務時自己寫的話：\n" + notes.prefix(8).map { "・\($0)" }.joined(separator: "\n") + "\n"
        }
        let chats = stuckLogs.map(\.content).filter { !$0.isEmpty }
        if !chats.isEmpty {
            s += "\n這週卡關對話的紀錄（找出哪些做法真的讓他重新推進）：\n"
                + chats.prefix(5).map { "・\($0)" }.joined(separator: "\n") + "\n"
        }
        return s
    }

    private static func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: d)
    }
    private static func weekday(_ d: Date) -> String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return "週" + names[Calendar.current.component(.weekday, from: d) - 1]
    }
    private static func slot(_ d: Date) -> String {
        switch Calendar.current.component(.hour, from: d) {
        case 5..<12:  "早上"
        case 12..<18: "下午"
        case 18..<23: "晚上"
        default:      "深夜"
        }
    }
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
    /// gpt-5 系列的話多程度（low/medium/high）。low 實測讓聊天泡泡中位數只剩約 54 字，
    /// 改用 medium；Prompt 的每輪字數上限與 150 字程式保險絲仍會防止回覆失控。
    static let chatVerbosity = "medium"
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
            // §02 拆分是三值：只有 recommended 才推薦。possible 不得主動推薦，
            // 所以這裡以 analysis 為準覆寫掉模型自己填的那顆 bool。
            if let relevance = reply.analysis?.splitRelevance, !relevance.isEmpty {
                reply.recommendSplit = relevance == "recommended"
            }
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
        // 狀況備註是使用者自己寫的卡點描述 —— 拆分要針對它，不是泛泛拆一個任務名稱
        if let note = task.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            user += "\n\n使用者自己寫的狀況備註（最重要的線索）：「\(note)」"
            user += "\n拆出來的子任務必須回應這段備註裡的卡點。"
            user += "他寫「不知道從哪開始」就把第一步縮到極小；寫「太多細節」就先拆出釐清範圍的步驟。"
        }
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

    /// 週回饋文字（給 B 的 FeedbackView 歷史週次區塊用，TEAM_PLAN Batch 3）
    ///
    /// 回傳 nil ＝這週沒有任何活動，呼叫端不要顯示 AI 區塊（也不會打 API）。
    ///
    /// **快取是必要的不是最佳化**：回饋頁一次渲染 12 週，每次 `.task` 都打一次
    /// 就是 12 次 API＋12 份費用，而且捲上捲下會重打。同一週在同一次啟動內只算一次。
    func weeklyFeedback(_ week: WeeklyStats) async throws -> String? {
        guard !week.isBarren else { return nil }

        let key = Calendar.current.startOfDay(for: week.startDate)
        if let cached = weeklyCache[key] { return cached }

        if useMock {
            try? await Task.sleep(nanoseconds: 400_000_000)
            let text = Self.weeklyFallback(week)
            weeklyCache[key] = text
            return text
        }

        do {
            let raw = try await callChat([
                ["role": "system", "content": PromptBuilder.weeklySystem()],
                ["role": "user", "content": week.digest]
            ], wantJSON: false, verbosity: "medium")   // 規格要約 200 字，low 會只吐兩句
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            weeklyCache[key] = text
            return text
        } catch {
            guard fallbackToMockOnFailure else { throw error }
            degrade(error, "週回饋")
            return Self.weeklyFallback(week)
        }
    }

    /// 週回饋快取。key = 該週第一天（startOfDay）。只活在記憶體，重開 App 會重算。
    private var weeklyCache: [Date: String] = [:]

    /// 離線／降級版。維持規格的三段結構，數字全部來自本地統計 —— 不編造，也不說「模式」。
    nonisolated static func weeklyFallback(_ week: WeeklyStats) -> String {
        var s = week.doneCount > 0
            ? "這週你完成了 \(week.doneCount) 件事，這是真的有在往前走。\n\n"
            : "這週雖然沒有完成的紀錄，你還是有打開它、看過它。\n\n"
        s += "### 這週的卡關時刻\n"
        s += week.stuckCount > 0
            ? "你用了 \(week.stuckCount) 次卡關解套。卡住之後願意去找方法，本身就是一種推進。\n\n"
            : "這週沒有留下卡關的紀錄。\n\n"
        s += "### 給這週的你\n"
        s += "累積了 \(week.totalWool)g 羊毛。下週不用加碼，維持現在的節奏就好。"
        return s
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
        // mode 是狀態不是每輪重算：模型沒填就沿用，否則使用者一按「給我下一步」
        // 下一輪就又飄回追問模式（§04 明講 direct_next_step 原則上不再探索型追問）
        if merged.mode.isEmpty { merged.mode = previous.mode }
        // 這兩個是「關於使用者的長期事實」，一旦問出來就不該消失
        if merged.effectiveMethods.isEmpty  { merged.effectiveMethods = previous.effectiveMethods }
        if merged.avoidRecommending.isEmpty { merged.avoidRecommending = previous.avoidRecommending }
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
