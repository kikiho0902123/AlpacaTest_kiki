# C 線接口規格書（INTERFACES.md）

> **交接文件**：工程師 C（AI 線）對外提供的所有接口。開工後把這份檔案放進 repo 根目錄，
> A/B 對接一律以此為準。契約（TEAM_PLAN §5）定死的部分照抄；其餘為 C 自訂、已定案。
> 最後更新：2026-08-15 早上（開工前）。

---

## 1. AIService（契約 §5，簽名不可改）

```swift
@MainActor
final class AIService {
    static let shared = AIService()
    var useMock = true        // C 串通真 API 前保持 true；也是離線 demo 模式

    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String) async throws -> StuckReply

    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?) async throws -> [String]

    func summarize(messages: [ChatMessage]) async throws -> String
}

struct StuckReply {
    var text: String              // AI 訊息
    var quickOptions: [String]    // 輕量選項（R2+：很接近/有一部分對/…）
    var recommendSplit: Bool      // STK-02F：符合條件才 true
    var isClosing: Bool           // Round 5+ 收斂語氣
}
```

- **A/B 原則上不需要直接呼叫 AIService**——聊天/拆分/記錄的 UI 都由 C 的元件包好了（見 §2）。
  例外：B 做週回饋文字（Batch 3）時再找 C 加方法。
- `useMock` 切換：`AIService.shared.useMock = false`（C 驗證 API 通了會廣播通知全隊）。
- 錯誤處理：所有方法可能 throw（斷網/API 掛）。C 的 UI 已內建 fallback，不會 crash。
- 內建行為（呼叫端不用管）：安全層關鍵詞檢查（命中不打 API、回 1925 關懷訊息）、
  429/5xx 退避重試 ×2（1s/3s）、JSON parse 失敗 fallback。

## 2. C 提供的畫面元件（呼叫方式）

### StuckChatView — 卡關聊天室（STK-02~05 全包）

```swift
.fullScreenCover(item: $chatTask) { StuckChatView(task: $0) }
```

- **呼叫前先彈 STK-01 確認**（用下面的 StuckConfirmModal）。
- 內部自己處理：8 輪、R1 chips、輕量選項、拆分推薦、R8 鎖輸入、
  離開確認（STK-03）、AI Summary（STK-04）、沒幫助回饋（STK-05）。
- 結束時 C 內部會做：寫 `TaskLog(type: "chatSummary")` 到該任務、
  `RewardEngine.grant(.stuckChatDone)`。**A 不要在這條路徑重複 grant。**
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
    SplitFlowModal(task: $0, source: .startAsk)          // TOD-04「是，我要拆分」
    SplitFlowModal(task: $0, source: .manual)            // 任務卡「拆分」鈕
    // .fromChat 只有 C 自己在聊天室內用，A 不會碰到
}
```

- `onFinished: (() -> Void)?` 選填：拆分確認後、Modal 關閉時呼叫（A 通常不需要，
  首頁刷新聽 `.taskSplit` 通知即可）。
- 確認拆分時 C 內部會做：建子任務（`parentID` = 母任務 id、繼承 category/subcategory/
  colorHex/startDate/isUrgent、`sortOrder` 依序）、母任務 `status = "split"`、
  寫 `TaskLog(type: "split")`、`RewardEngine.grant(.acceptSplit)`、
  `post .taskSplit（object = 母任務 UUID）`。
- **子任務的 status 是 "notStarted"**：使用者按「開始」時是 A 的卡片邏輯，
  記得 `parentID != nil` 時用 `grant(.startSubtask)`（15g，規格固定）。

### TaskRecordSheet — 任務記錄（TOD-07）

```swift
.sheet(item: $recordTask) { TaskRecordSheet(task: $0) }   // 自帶 .medium/.large detents
```

## 3. 資料寫入的分工（誰寫哪種 TaskLog）

| TaskLog.type | 誰寫 | 時機 |
|---|---|---|
| `chatSummary` | **C** | 離開聊天室「離開並記錄」/ 拆分結束（記在**母任務**） |
| `split` | **C** | 確認拆分 |
| `noHelpFeedback` | **C** | STK-05 填了原因 |
| `startNote` | A | 開始任務含備註時（若有做） |
| `completion` | B | TOD-06 完成記錄 |

## 4. RewardEngine 呼叫點（C 已呼叫的，別人不要重複）

| 事件 | 呼叫者 | 位置 |
|---|---|---|
| `.stuckChatDone` (40g) | **C** | 聊天室離開並記錄時 |
| `.acceptSplit` (30g) | **C** | 確認拆分時 |
| `.startTask` / `.startSubtask` | A | 任務卡「開始」 |
| `.complete(cx)` / `.completionNoteBonus` | B | 完成流程 |

## 5. 通知（契約 §6）

- C **發**：`.taskSplit`（object = 母任務 UUID）。A 聽這個刷新首頁。
- C 不聽任何通知。

## 6. R1 卡點 Chips

- 預設 10 顆寫死在 `ChatComponents.swift` 的 `StuckChips.defaults`（陣列，要改直接編輯）。
- AI 若在 R1 回了自己的 `quickOptions`，會取代預設（`StuckChips.resolve` 決定）。
  目前 prompt 指示 AI R1 留空 → 用預設。兩條路都通，改 prompt 即可切換。

## 7. 輪次規則（呼叫端不用管，寫給看 code 的人）

- `round = 該 session 使用者訊息數 + 1`；R1 = AI 開場（0 則使用者訊息）。
- 第 7 則使用者訊息的回覆 = Round 8 Final Closure → 鎖輸入＋休息 15 分鐘提示。
- Safety 觸發（自傷關鍵詞）不受鎖限制；命中時不打 API、回固定關懷訊息＋1925。

## 8. ScoringEngine / SeedData

```swift
// 給 AI 餵歷史（C 內部用；B 做回饋區想重用可以直接呼叫）
ScoringEngine.relevantHistory(for: task, context: modelContext) -> [HistoricalTaskSummary]

// App 啟動時載入 demo 資料（冪等，有資料就跳過）
SeedData.loadIfNeeded(context: modelContext)
```

- **需要 A 配合的唯一一行**：在 App 根 view 加
  `.task { SeedData.loadIfNeeded(context: modelContext) }`（或 A 指定位置，開工時對一下）。
- Seed 內容：5 筆歷史任務＋TaskLogs、今日任務「讀日文三小時」（拆分 demo）＋
  「寫實習週報」（卡關 demo，會引用「寫履歷自傳」的卡關紀錄）、本週 4 天已收割
  DailyStat（620/980/450/1130g）、UserProfile（woolBankG=500，差 100g 織手套 = demo 劇本）。

## 9. Secrets / API 設定

- repo 只放 `Secrets.example.swift`；每人 clone 後複製改名 `Secrets.swift` 貼自己的 key。
- **`.gitignore` 必須含 `Secrets.swift`**（A 建 repo 時；C 第一次 push 前檢查）。
- 模型設定在 `AIService.swift` 的 `AIConfig.model`（預設 `gpt-5-mini`，
  以 `C_Line/apitest.swift` 實測結果為準）。

## 10. C 擁有的檔案（放進 repo 的位置）

```
Services/AIService.swift        Services/PromptBuilder.swift
Services/ScoringEngine.swift    Services/SeedData.swift
Views/Chat/StuckChatView.swift  Views/Chat/ChatComponents.swift
Views/Chat/SplitFlowModal.swift Views/Chat/TaskRecordSheet.swift
Secrets.example.swift           C_INTERFACES.md（本文件）
```

依賴（別人的、C 只呼叫）：`Models.swift`（A）、`RewardEngine`（B）、
`ConfirmModal(title:message:primary:secondary:)` 樣板（A，簽名以 A 實作為準，
不一致時 C 開工 15 分鐘內自行適配呼叫點——共 4 處）。

## 11. 測試

- 邏輯層測試在 `C_Line/LogicTests`（22 個測試，涵蓋計分/解析/安全層/seed/mock 劇本）：
  `cd C_Line/LogicTests && swift test`
- UI 用模擬器實走驗證（已通過：卡關 R1→R3 →拆分推薦→拆分→Summary→記錄）。
