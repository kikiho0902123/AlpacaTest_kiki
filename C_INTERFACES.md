# C 線接口規格書（INTERFACES.md）

> **交接文件**：工程師 C（AI 線）對外提供的所有接口。A/B 對接一律以此為準。
> 契約（TEAM_PLAN §5）定死的部分照抄；其餘為 C 自訂、已定案。
> **最後更新：2026-08-15 下午**（週回饋 API 上線、Context Analysis 引擎完成後）。

---

## 1. AIService

```swift
@MainActor
final class AIService {
    static let shared = AIService()

    /// 有 key 就走真 API，沒 key 自動走離線罐頭 → A/B 不用設定就能開發。
    /// 現場網路掛掉時手動設 true 可完整離線 demo。
    var useMock = Secrets.openAIKey.isEmpty

    /// API 掛掉時不把錯誤丟給使用者，直接用罐頭讓流程走完。除錯時設 false 讓它照常 throw。
    var fallbackToMockOnFailure = true

    // 卡關聊天（STK-02）
    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String,
                   previous: ContextAnalysis? = nil) async throws -> StuckReply

    // 拆分建議（SPL-01）
    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?,
                      analysis: ContextAnalysis? = nil) async throws -> [String]

    // 離開時的 Summary（STK-04）
    func summarize(messages: [ChatMessage],
                   analysis: ContextAnalysis? = nil) async throws -> String

    // 週回饋文字（給 B 的回饋頁）→ 見 §9
    func weeklyFeedback(_ week: WeeklyStats) async throws -> String?
}
```

新增的 `previous:` / `analysis:` 都有預設值，**舊呼叫方式不會壞**。

### StuckReply

```swift
struct StuckReply: Codable {
    var text: String              // AI 訊息（已過 150 字保險絲）
    var quickOptions: [String]    // 輕量選項（R2+）
    var recommendSplit: Bool      // STK-02F：符合條件才 true
    var isClosing: Bool           // R5+ 收斂語氣
    var analysis: ContextAnalysis?   // ★ 內部分析，使用者永遠看不到
}
```

### ContextAnalysis（設計師 02｜Context Analysis Engine）

**A/B 不需要碰這個**，它是 C 內部三個 AI 呼叫之間的共用判讀。列在這裡是因為它現在出現在
`stuckChat` / `suggestSplit` / `summarize` 三個簽名上，看 code 的人會問。

```swift
struct ContextAnalysis: Codable, Equatable {
    var blockers: [String]           // 所有卡點
    var primary: String              // 主要阻力
    var hypothesis: String           // 這輪的工作假設
    var confidence: String           // low / medium / high
    var energy: String               // low / medium / high
    var tried: [String]              // 已經給過的建議（防重複推薦）
    var mode: String                 // ★ 見 ChatMode
    var needClarification: Bool      // 這輪該不該追問
    var clarificationQuestion: String
    var splitRelevance: String       // recommended / possible / not_relevant
    var splitReason: String
    var effectiveMethods: [String]   // 過去對他有效的做法
    var avoidRecommending: [String]  // 已證實無效，不要再推
    var readyToClose: Bool           // ★ 可以收尾了（UI 出「這次先到這裡」）
}

enum ChatMode {   // 對話狀態機（設計師 03/04）
    clarification / initial_assistance / direct_next_step
    / deep_conversation / progressive_closure / final_closure
}
```

兩個關鍵行為，寫在這裡免得日後被當成 bug：

- **`recommendSplit` 以 `splitRelevance` 為準**：只有 `recommended` 會變 true。
  `possible` 不主動推薦（設計師 02 的三值定義）。
- **狀態切換由使用者行為決定，不是由輪次決定**。使用者在哪一輪按「給我下一步」，
  就在那一輪切成 `direct_next_step`。文件裡只有 R1 和 R5–R8 有指定行為，
  中間是狀態機在跑。

### 內建行為（呼叫端不用管）

- 安全層關鍵詞檢查：命中**不打 API**，回固定關懷訊息＋台灣安心專線 1925，不受輪次限制。
- 429 / 5xx / 斷網：退避重試 ×2（1s / 3s）。
- JSON parse 失敗 → 全文塞進 `text`，永不 crash。
- 所有方法都可能 throw，但 `fallbackToMockOnFailure = true` 時 UI 端不會看到錯誤。

## 2. C 提供的畫面元件（呼叫方式）

### StuckChatView — 卡關聊天室（STK-02~05 全包）

```swift
.fullScreenCover(item: $chatTask) { StuckChatView(task: $0) }
```

- **呼叫前先彈 STK-01 確認**（用下面的 StuckConfirmModal）。
- 內部自己處理：8 輪、R1 chips、輕量選項、拆分推薦、R8 鎖輸入、
  離開確認（STK-03）、AI Summary（STK-04）、有幫助／沒幫助回饋（STK-05）。
- 結束時 C 內部會做：寫 `TaskLog(type: "chatSummary")`、`RewardEngine.grant(.stuckChatDone)`。
  **A 不要在這條路徑重複 grant。**
- **一進來就按離開（沒有任何使用者訊息）不會留記錄、不打摘要 API、不發羊毛**，直接關閉。
- 從聊天進拆分並完成 → 自動走記錄流程後關閉（呼叫端不用做事）。

### StuckConfirmModal — STK-01 確認（給 A 的 TodayView 用）

```swift
.overlay {
    if let task = stuckCandidate {
        StuckConfirmModal(
            onGo: { stuckCandidate = nil; chatTask = task },
            onCancel: { stuckCandidate = nil })
    }
}
```

### SplitFlowModal — 拆分全流程（SPL-01~04）

```swift
.sheet(item: $splitTask) {
    SplitFlowModal(task: $0, source: .startAsk)   // TOD-04「是，我要拆分」
    SplitFlowModal(task: $0, source: .manual)     // 任務卡「拆分」鈕
    // .fromChat + analysis: 只有 C 自己在聊天室內用，A 不會碰到
}
```

- `onFinished: (() -> Void)?` 選填（A 通常不需要，首頁刷新聽 `.taskSplit` 即可）。
- 確認拆分時 C 內部會做：建子任務（`parentID`、繼承 category/subcategory/colorHex/
  startDate/isUrgent、`sortOrder` 依序）、母任務 `status = "split"`、
  寫 `TaskLog(type: "split")`、`grant(.acceptSplit)`、`post .taskSplit`（object = 母任務 UUID）。
- **子任務 status 是 `"notStarted"`**：使用者按「開始」是 A 的卡片邏輯，
  `parentID != nil` 時記得用 `grant(.startSubtask)`（15g，規格固定）。

### TaskRecordSheet — 任務記錄（TOD-07）

```swift
.sheet(item: $recordTask) { TaskRecordSheet(task: $0) }   // 自帶 .medium/.large detents
```

### MarkdownText — 給 B 用的簡易 Markdown 渲染

```swift
MarkdownText(raw: someAIText)
```

SwiftUI 的 `Text` **只對字串常數解析 Markdown**，變數不會生效，而且原生也沒有標題／
條列的區塊排版。這個 view 自己切行處理：`# ~ #### ` 標題、`- `／`• `／`* ` 條列、
整行 `**粗體**` 視為標題，其餘為段落。
**週回饋文字含 `### ` 小標，B 要用這個 view 渲染**（用普通 `Text` 會看到裸露的 `###`）。

## 3. 資料寫入的分工（誰寫哪種 TaskLog）

| TaskLog.type | 誰寫 | 時機 |
|---|---|---|
| `chatSummary` | **C** | 離開聊天室「離開並記錄」/ 拆分結束（記在**母任務**） |
| `split` | **C** | 確認拆分 |
| `noHelpFeedback` | **C** | STK-05 填了原因 |
| `chatHelpful` | **C** | STK-04 按「對我有幫助」（★ 新增，契約沒定義） |
| `startNote` | A | 開始任務含備註時 |
| `completion` | B | TOD-06 完成記錄 |

> `chatHelpful` 是 C 自己加的：契約只定義了「沒幫助」會留記錄，
> 「有幫助」原本什麼都不寫＝白丟一筆正向訊號。**B 的回饋頁要不要顯示它由 B 決定，
> 不顯示也完全無害。**

## 4. RewardEngine 呼叫點（C 已呼叫的，別人不要重複）

| 事件 | 呼叫者 | 位置 |
|---|---|---|
| `.stuckChatDone` (40g) | **C** | 聊天室離開並記錄時（**沒有實際對話則不發**） |
| `.acceptSplit` (30g) | **C** | 確認拆分時 |
| `.startTask` / `.startSubtask` | A | 任務卡「開始」 |
| `.complete(cx)` / `.completionNoteBonus` | B | 完成流程 |

## 5. 通知（契約 §6）

- C **發**：`.taskSplit`（object = 母任務 UUID）。A 聽這個刷新首頁。
- C 不聽任何通知。

## 6. R1 卡點 Chips

- 預設 10 顆寫死在 `ChatComponents.swift` 的 `StuckChips.defaults`（陣列，要改直接編輯）。
- AI 若在 R1 回了自己的 `quickOptions` 會取代預設（`StuckChips.resolve` 決定）。
  目前 prompt 指示 AI R1 留空 → 用預設。兩條路都通，改 prompt 即可切換。

## 7. 輪次規則（呼叫端不用管，寫給看 code 的人）

- `round = 該 session 使用者訊息數 + 1`；R1 = AI 開場（0 則使用者訊息）。
- 第 7 則使用者訊息的回覆 = Round 8 Final Closure → 鎖輸入＋休息 15 分鐘提示。
- **R5–R8 各有不同的收束強度**（設計師 04），不是同一段指令重複四次。
- `readyToClose = true` 時 UI 會多出一顆「這次先到這裡」，讓使用者不必硬撐到 R8。
- Safety 觸發不受鎖限制；命中時不打 API、回固定關懷訊息＋1925。

## 8. 任務的「狀況備註」（TSK-01，A 做的欄位）

`TodoTask.note` 只要有值，**卡關聊天和拆分建議都會讀到**，而且權重最高：

- 卡關：R1 會直接接住備註內容往下推進，**不會再問備註裡已經回答過的問題**。
- 拆分：子任務必須回應備註裡的卡點（寫「不知道從哪開始」→ 第一步縮到極小）。
- 空白或全空白字元時整段不送，退回一般行為。

**A/B 不用做任何事**，把 `note` 存進去就會生效。

## 9. 週回饋 API（給 B 的 FeedbackView）★ 新增

**整合狀態：✅ 已接入。** `FeedbackView.HistoricalWeeklyBlock` 會以週起始日作為穩定識別，
載入時顯示整理中狀態；有資料時用 `MarkdownText` 顯示三段式回饋；空白週維持資料不足提示。

```swift
struct WeeklyStats {
    var startDate: Date
    var endDate: Date
    var stats: [DailyStat]     // 這週的 7 筆
    var logs:  [TaskLog]       // 這週的 log
    var tasks: [TodoTask] = [] // ★ 要傳，否則分析不出「卡在哪個分類」
}

func weeklyFeedback(_ week: WeeklyStats) async throws -> String?
```

B 手上已經有這三包（`WeeklyFeedbackData` 裡的 `stats` / `logs` / `tasks`），直接傳：

```swift
@State private var feedbackText: String?

// 在 HistoricalWeeklyBlock 裡
.task {
    feedbackText = try? await AIService.shared.weeklyFeedback(
        WeeklyStats(startDate: week.startDate, endDate: week.endDate,
                    stats: week.stats, logs: week.logs, tasks: week.tasks))
}

if let feedbackText {
    MarkdownText(raw: feedbackText)     // ★ 用 MarkdownText，文字含 ### 小標
} else {
    WeeklyFeedbackPlaceholder()          // 沒資料的週維持現狀
}
```

**三個必須知道的行為：**

1. **回傳 `nil` = 這週完全沒活動**（沒完成、沒開始、沒卡關、沒 log）。
   這時**不會打 API**，呼叫端請維持 placeholder 或整段不顯示。
   12 週裡大部分是空的，這是省錢也是防止畫面出現「你這週很棒」的空話。
2. **內建快取**，key = 該週第一天。同一週在同一次啟動內只算一次。
   回饋頁一次渲染 12 週，沒有快取的話捲上捲下會重複打 API。
   快取只活在記憶體，重開 App 會重算。
3. **輸出是三段式**（設計師規格），約 200 字：
   一句肯定 → `### 這週的卡關時刻` → `### 給這週的你`（含 1–2 個下週方向）。
   API 掛掉時降級文字**也維持這三段**，數字用本地統計，版面不會塌。

實測（`swift test --filter WeeklyFeedback`）：231–249 字、2.7–2.8 秒。
素材有重複現象時會下「模式」判斷；只有一次時會自動收斂成「這週有一次…」——
設計師規格「不把單次事件描述成長期模式」由程式先在素材裡標記次數來保證。

## 10. ScoringEngine / SeedData

```swift
// 給 AI 餵歷史（C 內部用；B 做回饋區想重用可以直接呼叫）
ScoringEngine.relevantHistory(for: task, context: modelContext) -> [HistoricalTaskSummary]

// App 啟動時載入 demo 資料（冪等，有資料就跳過）
SeedData.loadIfNeeded(context: modelContext)
```

- Seed 內容：5 筆歷史任務＋TaskLogs、今日任務「讀日文三小時」（拆分 demo）＋
  「寫實習週報」（卡關 demo，會引用「寫履歷自傳」的卡關紀錄）、本週 4 天已收割
  DailyStat（620/980/450/1130g）、UserProfile（woolBankG=500，差 100g 織手套 = demo 劇本）。

## 11. Secrets / API 設定

**新 clone 的人第一件事**（不做的話編譯失敗，因為 `Secrets.swift` 被 gitignore）：

```bash
cd AlpacaTest_kiki/AlpacaTest_kiki
cp Secrets.example.swift Secrets.swift
# 然後打開 Secrets.swift，把最後三行的 // 拿掉，貼上自己的 key
```

- 範例檔內容是**整段註解掉的**（避免它和真的 `Secrets.swift` 同時定義 `Secrets` 而衝突），
  所以複製完**一定要解註解**。
- key **不要貼進任何聊天視窗或群組**——OpenAI 的掃描器會自動撤銷外洩的 key。
- `.gitignore` 必須含 `Secrets.swift`；每次 push 前掃一次 `git status`。
- **沒有 key 也能開發**：`useMock` 會自動變 true，全部走罐頭回應，App 正常跑。

模型設定在 `AIService.swift` 的 `AIConfig`：

| 設定 | 值 | 為什麼 |
|---|---|---|
| `model` | `gpt-5.5` | 實測比 gpt-5-mini 快一倍且更準（見 `AIConfig` 註解） |
| `reasoningEffort` | `low` | `minimal` 會忽略字數自檢，話變超長 |
| `chatVerbosity` | `low` | 聊天泡泡要短；摘要／週回饋另外用 `medium` |
| `serviceTier` | `priority` | 實測沒有明顯變快，留著是防 demo 當天 API 壅塞 |

> ⚠️ `reasoning_effort` 的最低檔在 gpt-5.0 家族叫 `minimal`、5.1 之後改叫 `none`，
> **送錯會整包 400，不是降級**。`AIConfig.lowestEffort` 會依 model 名稱自動選。

## 12. C 擁有的檔案

```
Services/AIService.swift        Services/PromptBuilder.swift
Services/ScoringEngine.swift    Services/SeedData.swift
Views/Chat/StuckChatView.swift  Views/Chat/ChatComponents.swift
Views/Chat/SplitFlowModal.swift Views/Chat/TaskRecordSheet.swift
Secrets.example.swift           C_Line/INTERFACES.md（本文件）
```

依賴（別人的、C 只呼叫）：`Models.swift`（A）、`RewardEngine`（B）、
`ConfirmModal(title:message:primary:secondary:)` 樣板（A）。

## 13. 測試

```bash
cd C_Line/LogicTests
swift test --filter AppLogicTests      # 55 個，不花錢不打網路，隨時可跑
swift test --filter LiveAPI            # ↓ 以下會打真 API、會花錢
swift test --filter WeeklyFeedback     # 週回饋三段格式＋單次事件不得稱模式
swift test --filter OffScript          # 使用者不照劇本走時 mode 有沒有正確切換
swift test --filter ModelCompare       # 同一份 prompt 橫向比較不同模型
```

- `Sources/AppLogic/` 是指向 app 原始碼的**符號連結**，不是複本——單一事實來源。
- UI 用模擬器實走驗證（已通過：卡關 R1→R3 →拆分推薦→拆分→Summary→記錄）。
- 真 API 測試會把完整輸出寫到 scratchpad 的 `.md`（XCTest 會截斷 stdout，讀檔才看得到全文）。
