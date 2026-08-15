//
//  Secrets.example.swift
//  AlpacaTest_kiki
//
//  API key 的範本。真正的 `Secrets.swift` 被 gitignore（TEAM_PLAN §1.5），
//  所以 **新 clone 下來一定會編譯失敗**，直到你做完下面三步。
//
//  ── 新 clone 必做（30 秒）────────────────────────────
//    cd AlpacaTest_kiki/AlpacaTest_kiki
//    cp Secrets.example.swift Secrets.swift
//
//  然後打開剛複製出來的 Secrets.swift：
//    1. 把最後三行的 `//` 拿掉（← 最常忘記的一步，忘了等於沒複製）
//    2. 把 sk-REPLACE_ME 換成自己的 key
//    3. 確認 Xcode 有把 Secrets.swift 加進 target（沒有的話拖進專案）
//
//  ── 沒有 key 也能開發 ──────────────────────────────
//  openAIKey 留空字串就好。AIService 會自動 useMock = true，
//  全部走離線罐頭回應，App 一樣跑得完整流程。只有 C 和 demo 機器需要真 key。
//
//  ── 安全 ───────────────────────────────────────────
//  · 絕對不要 commit Secrets.swift
//  · 絕對不要把 key 貼進群組聊天／截圖 —— OpenAI 的掃描器偵測到外洩會自動撤銷
//  · 要給另一台 demo 機器：私下傳，用完刪掉
//
//  這份範本刻意整段註解掉：這樣它不定義任何符號，
//  就算你已經有真的 Secrets.swift 也不會撞在一起。
//
//  enum Secrets {
//      static let openAIKey = "sk-REPLACE_ME"
//  }
