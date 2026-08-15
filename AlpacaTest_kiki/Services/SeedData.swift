//
//  SeedData.swift
//  [C 擁有 — 明天複製到 repo 的 Services/SeedData.swift]
//
//  Demo 的靈魂。App 第一次啟動自動載入：
//  - 5 筆 30 天內歷史任務（讓 ScoringEngine 選得出 ≥3 筆）＋ TaskLogs
//  - 2 筆今日任務（「讀日文三小時」給拆分 demo、「寫實習週報」給卡關 demo）
//  - 本週前幾天的 DailyStat（回饋區才有東西看）
//  - UserProfile：woolBankG=500（織手套 600g 差一點點，收割完剛好夠 = demo 劇本）
//

import Foundation
import SwiftData

enum SeedData {

    /// 已有資料就跳過；乾淨模擬器（Erase All Content）→ 重裝 → 自動載入
    static func loadIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }

        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: .now))! }

        // MARK: UserProfile（單例）
        let profile = UserProfile()
        profile.woolBankG = 500
        profile.onboardingJSON = """
        {"身份":"大學生","平均睡眠":"6-7小時","常見任務類型":["報告","語言學習","實習工作"],\
        "容易卡住的類型":["長篇寫作","範圍模糊的任務"],"常見卡關狀況":["不知道從哪開始","開始前一直滑手機"],\
        "有效的方法":["把任務切小","先做10分鐘"],"不想聽到的建議":["你就是不夠自律"]}
        """
        context.insert(profile)

        // MARK: 歷史任務 ×5（status=done，附 TaskLog）
        struct Old {
            let name: String; let cat: String; let sub: String?
            let days: Int; let cx: Int; let note: String?; let stuck: Bool
        }
        let olds: [Old] = [
            Old(name: "寫履歷自傳", cat: "求職", sub: "文件", days: 6, cx: 2,
                note: "拖了三天，最後用拆小段的方式寫完，其實沒那麼難", stuck: true),
            Old(name: "讀日文 N5 文法第三章", cat: "學習", sub: "日文", days: 4, cx: 1,
                note: "早上讀比晚上有效率多了", stuck: false),
            Old(name: "整理實習作品集", cat: "求職", sub: "文件", days: 12, cx: 2,
                note: "先列清單再整理，兩小時就完成了", stuck: false),
            Old(name: "背日文單字 50 個", cat: "學習", sub: "日文", days: 9, cx: 0,
                note: nil, stuck: false),
            Old(name: "準備專題期中報告", cat: "學校", sub: "專題", days: 24, cx: 2,
                note: "上台前很緊張，但準備充分就還好", stuck: true),
        ]
        for old in olds {
            let t = TodoTask(name: old.name)
            t.category = old.cat
            t.subcategory = old.sub
            t.complexity = old.cx
            t.status = "done"
            t.progress = 1.0
            t.startDate = daysAgo(old.days)
            t.createdAt = daysAgo(old.days + 1)
            context.insert(t)
            if let note = old.note {
                let log = TaskLog(taskID: t.id, type: "completion", content: note)
                log.timestamp = daysAgo(old.days)
                context.insert(log)
            }
            if old.stuck {
                let log = TaskLog(taskID: t.id, type: "chatSummary",
                                  content: "當時卡在不知道從哪開始，聊完決定先寫最有把握的段落，門檻降低後就順了。")
                log.timestamp = daysAgo(old.days)
                context.insert(log)
            }
        }

        // MARK: 今日任務 ×2（demo 主角）
        let big = TodoTask(name: "讀日文三小時")          // demo：開始 → 是否拆分 → AI 拆分
        big.category = "學習"; big.subcategory = "日文"
        big.complexity = 2; big.isMustToday = true
        big.startDate = cal.startOfDay(for: .now)
        context.insert(big)

        let work = TodoTask(name: "寫實習週報")           // demo：卡住了 → AI 聊天（會引用「寫履歷自傳」的卡關紀錄）
        work.category = "求職"; work.subcategory = "文件"
        work.complexity = 1
        work.startDate = cal.startOfDay(for: .now)
        context.insert(work)

        // MARK: 本週 DailyStat（過去幾天已收割 → 回饋區有資料）
        for (offset, wool) in [(4, 620), (3, 980), (2, 450), (1, 1130)] {
            let stat = DailyStat(date: daysAgo(offset))
            stat.woolG = wool
            stat.startCount = Int.random(in: 2...5)
            stat.stuckCount = Int.random(in: 0...2)
            stat.doneCount = Int.random(in: 1...4)
            stat.isClosed = true
            stat.harvested = true
            context.insert(stat)
        }
        let today = DailyStat(date: cal.startOfDay(for: .now))
        context.insert(today)

        try? context.save()
        print("🌱 SeedData 載入完成")
    }
}
