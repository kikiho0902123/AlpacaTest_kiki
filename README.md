# loomi

一款以羊駝養成為獎勵機制的 iOS 待辦事項工具，在使用者卡關時提供 AI 陪伴與任務拆分，讓「願意開始」和「主動求助」本身就能獲得正向回饋。

| | |
|---|---|
| 隊伍編號 | 9 |
| 隊名 | kiki's team |
| 產品名稱 | loomi |

---

## 連結

- **GitHub Repo**：https://github.com/kikiho0902123/AlpacaTest_kiki
- **Demo 網址**：無（iOS 原生 App，未部署網頁版）
- **Demo 影片**：https://drive.google.com/file/d/1w1F_p8TvUk0rD4y7gIPEAKbLl65d18Ug/view?usp=drivesdk
- **簡報**：https://docs.google.com/presentation/d/1S5DXpjnJpv0bcpgrI4gOV77BbCPYIdDKN5AS7tJPwbU/edit

---

## 使用的 AI 工具

### 開發工具

| 工具 | 用途 |
|---|---|
| Claude Code（Anthropic） | 主要開發，架構重構、SwiftUI 實作 |
| ChatGPT（OpenAI） | 部分動畫實作 |
| Claude in Xcode / Codex in Xcode | IDE 內建 agent |

### 產品內建 AI

- **OpenAI API（gpt-5.5）** — 卡關對話、任務拆分建議、自然語言建立任務

---

## 活動前既有程式碼

活動前一日（8/14 晚間）建立了 Xcode 專案骨架與資料模型定義，約 200 行，目的為避免當日早晨環境設定佔用開發時間。除此之外**無使用任何既有專案、開源專案或樣板**。

當日完成部分包含：全部 UI 實作、AI 串接、拆分與卡關流程、羊毛獎勵系統、月曆任務庫、自然語言建立任務、週回饋分析等，均可由 commit 歷史查證。

---

## 技術架構

- **SwiftUI + SwiftData**（本機儲存，無後端）
- 三位工程師並行開發，以**檔案所有權**與**共用契約**（資料模型 / `AIService` 介面 / `RewardEngine`）避免衝突
- OpenAI API 直接由 client 呼叫，**金鑰不入版控**

---

## 當日主要產出

- **任務管理**：建立／編輯／三態日期／分類／備註
- **AI 任務拆分**：三個入口，可編輯子任務後確認
- **AI 卡關陪伴**：快速回應選項、多輪對話、對話摘要回寫任務紀錄
- **自然語言建立任務**：一句話生成結構化任務，使用者確認後建立
- **羊毛獎勵系統**：開始／拆分／求助／完成皆給予回饋
- **月曆任務庫**：依日期瀏覽、未排任務區
- **每日結算與週回饋分析**

---

## 本機執行

需要 Xcode 26.5 以上與 iOS 26.5 模擬器。

```bash
git clone https://github.com/kikiho0902123/AlpacaTest_kiki.git
cd AlpacaTest_kiki
open AlpacaTest_kiki.xcodeproj
```

AI 功能需要自己的 OpenAI API key：

```bash
cp AlpacaTest_kiki/Secrets.example.swift AlpacaTest_kiki/Secrets.swift
# 在 Secrets.swift 填入 openAIKey
```

`Secrets.swift` 已列入 `.gitignore`，不會進版控。留空時 `AIService.useMock` 會自動為 `true`，全程使用離線罐頭回應，其餘功能不受影響。
