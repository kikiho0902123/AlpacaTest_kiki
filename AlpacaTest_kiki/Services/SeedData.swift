//
//  SeedData.swift
//  AlpacaTest_kiki
//
//  Local demo fixture:
//  - 20 realistic tasks across the previous complete week
//  - 5 stuck-help sessions (4 helpful, 1 not helpful)
//  - an empty current day so the demo can create its hero task through AI
//  - deterministic DailyStat snapshots for weekly feedback
//

import Foundation
import SwiftData

enum SeedData {

    private struct DemoTask {
        let day: Int
        let hour: Int
        let name: String
        let category: String
        let subcategory: String?
        let complexity: Int
        let status: String
        let progress: Double
        let note: String?
        let completionNote: String?
        let chatSummary: String?
        let wasHelpful: Bool?
        let noHelpFeedback: String?
    }

    /// Existing app data is preserved until the app container is removed. On a clean install,
    /// the profile is absent and this fixture is inserted exactly once.
    static func loadIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let previousWeekStart = calendar.date(
            byAdding: .weekOfYear,
            value: -1,
            to: currentWeekStart
        ) ?? calendar.date(byAdding: .day, value: -7, to: today) ?? today

        func timestamp(day: Int, hour: Int, minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: day, to: previousWeekStart) ?? previousWeekStart
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        }

        // MARK: User profile

        let profile = UserProfile()
        profile.name = "小安"
        profile.woolBankG = 500
        profile.onboardingJSON = """
        {"身份":["大學生","產品實習生"],"平均睡眠":"6-7小時",\
        "常見任務類型":["實習文件","學校報告","求職準備","日文學習","生活雜務"],\
        "容易卡住的類型":["把零散資料整理成完整內容","需要從空白開始的寫作"],\
        "常見卡關狀況":["不知道從哪開始","想一次整理完整","晚上容易沒力氣"],\
        "有效的方法":["先建立具體骨架","先做10分鐘","先標出三個主題"],\
        "不想聽到的建議":["你就是不夠自律","籠統地叫我拆小一點"]}
        """
        context.insert(profile)

        // MARK: Previous complete week — 20 tasks

        let tasks: [DemoTask] = [
            DemoTask(
                day: 0, hour: 9, name: "整理實習晨會待辦", category: "實習", subcategory: "協作",
                complexity: 0, status: "done", progress: 1,
                note: "晨會後有幾件小事散在筆記裡，怕下午忘記。",
                completionNote: "把三個行動項目移進 Notion，順手補了負責人和期限，下午比較沒有一直回頭找筆記。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 0, hour: 19, name: "讀研究方法第四章", category: "學校", subcategory: "研究方法",
                complexity: 1, status: "started", progress: 0.7,
                note: "明天上課前要讀完，但晚上注意力有點散。",
                completionNote: nil, chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 0, hour: 21, name: "洗衣服和曬衣", category: "生活", subcategory: "家務",
                complexity: 0, status: "done", progress: 1,
                note: nil,
                completionNote: "洗完才發現有一件襯衫要手洗，雖然晚了一點，還是全部處理完了。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 1, hour: 12, name: "回覆學長的作品集建議", category: "求職", subcategory: "作品集",
                complexity: 0, status: "done", progress: 1,
                note: "想先確認哪些修改值得這週做。",
                completionNote: "午休先回覆並確認三個優先修改項目，沒有再拖著等一封完美的信。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 1, hour: 20, name: "整理使用者訪談逐字稿", category: "實習", subcategory: "研究",
                complexity: 2, status: "done", progress: 1,
                note: "逐字稿有四十多頁，看到整份文件就不知道該先整理哪裡。",
                completionNote: "先只標出需求、困惑和原話三種內容後，資料突然沒那麼亂；今晚整理完兩位受訪者，這個方法真的有用。",
                chatSummary: "卡點不是看不懂訪談內容，而是四十多頁逐字稿同時出現在眼前，讓起步成本太高。對話中沒有要求一次完成分類，而是先示範只標出需求、困惑和原話三個主題。使用者接受這個做法，決定先處理第一位受訪者的前十分鐘內容。",
                wasHelpful: true, noHelpFeedback: nil
            ),
            DemoTask(
                day: 1, hour: 22, name: "複習日文單字 30 個", category: "學習", subcategory: "日文",
                complexity: 0, status: "done", progress: 1,
                note: "只複習今天課堂出現的單字。",
                completionNote: "用通勤時存下來的單字清單複習，比重新翻整章課本輕鬆。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 2, hour: 21, name: "寫實習週報初稿", category: "實習", subcategory: "文件",
                complexity: 1, status: "done", progress: 1,
                note: "做了不少零碎工作，但打開空白文件後不知道怎麼寫成一篇週報。",
                completionNote: "先寫本週完成、遇到問題、下週計畫三個標題，再把事情放進去，二十五分鐘就有一版能交的初稿。",
                chatSummary: "使用者不是沒有內容，而是想在第一句就把整週工作說完整，因此一直停在空白頁。AI 根據先前整理資料的經驗，提出先建立「本週完成、遇到問題、下週計畫」三段空骨架，暫時不要求句子完整。使用者決定先花十分鐘只把零散事項放到對應標題下。",
                wasHelpful: true, noHelpFeedback: nil
            ),
            DemoTask(
                day: 2, hour: 15, name: "核對經濟學作業圖表", category: "學校", subcategory: "經濟學",
                complexity: 1, status: "done", progress: 1,
                note: "要確認座標名稱和資料年份有沒有放反。",
                completionNote: "對照原始資料逐張檢查，找到一張年份標錯，也補上了資料來源。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 2, hour: 18, name: "買下週早餐食材", category: "生活", subcategory: "採買",
                complexity: 0, status: "done", progress: 1,
                note: "優格、香蕉、蛋和吐司。",
                completionNote: "照清單買完，沒有因為肚子餓多拿一堆零食。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 3, hour: 22, name: "修改作品集專案說明", category: "求職", subcategory: "作品集",
                complexity: 2, status: "started", progress: 0.5,
                note: "知道舊版太像工作清單，但不知道怎麼改成有脈絡的故事。",
                completionNote: nil,
                chatSummary: "使用者想把作品集從工作清單改成有脈絡的案例，但對話只給出「把內容拆小、先改一段」的方向，沒有提供可直接套用的句型或段落範例。使用者嘗試後仍不知道第一段要怎麼寫，因此暫停在約一半進度，決定隔天再找一個實際案例參考。",
                wasHelpful: false,
                noHelpFeedback: "只叫我拆小一點還是太抽象；如果能給一個開頭句型或改寫範例，我會比較知道怎麼開始。"
            ),
            DemoTask(
                day: 3, hour: 16, name: "整理團隊會議筆記", category: "實習", subcategory: "協作",
                complexity: 1, status: "done", progress: 1,
                note: "把決策、待確認問題和負責人分開。",
                completionNote: "會後立刻整理成三區，主管回覆時可以直接找到尚未確認的問題。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 3, hour: 20, name: "跑步 20 分鐘", category: "健康", subcategory: "運動",
                complexity: 0, status: "started", progress: 0.2,
                note: "下班後下雨又很累，只換了衣服做五分鐘伸展。",
                completionNote: nil, chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 4, hour: 19, name: "準備專題簡報架構", category: "學校", subcategory: "專題",
                complexity: 2, status: "done", progress: 1,
                note: "資料很多，擔心漏掉重要內容，所以一直加投影片。",
                completionNote: "先固定問題、發現、下一步三張核心投影片，再把其他資料放附錄，簡報終於有主線。",
                chatSummary: "卡點來自擔心遺漏資料，導致使用者一直增加投影片而無法決定主線。AI 沒有繼續要求補資料，而是請他先只寫「問題、發現、下一步」三張投影片標題，其餘內容先移到附錄。使用者確認這個範圍做得到，決定先完成三張核心頁面再回頭檢查。",
                wasHelpful: true, noHelpFeedback: nil
            ),
            DemoTask(
                day: 4, hour: 17, name: "填寫實習工時表", category: "實習", subcategory: "行政",
                complexity: 0, status: "done", progress: 1,
                note: "補上週三忘記登記的兩個小時。",
                completionNote: "對照行事曆補齊後送出，沒有留到週一早上。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 4, hour: 13, name: "預約牙醫", category: "生活", subcategory: "健康行政",
                complexity: 0, status: "done", progress: 1,
                note: "避開週三下午實習會議。",
                completionNote: "約到下週六早上，順便把日期放進行事曆。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 5, hour: 9, name: "做日文 N5 模擬題", category: "學習", subcategory: "日文",
                complexity: 1, status: "done", progress: 1,
                note: "先完成語彙和文法兩部分，不硬做聽力。",
                completionNote: "錯最多的是助詞，已把八題錯題另外記下來，下次只複習這一組。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 5, hour: 14, name: "整理房間桌面", category: "生活", subcategory: "家務",
                complexity: 0, status: "done", progress: 1,
                note: "先清出可以放筆電的位置就好。",
                completionNote: "丟掉過期收據，也把充電線集中到同一個盒子；沒有順便翻整個房間。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 5, hour: 10, name: "列下週訪談問題", category: "實習", subcategory: "研究",
                complexity: 1, status: "done", progress: 1,
                note: "想問的東西很多，怕問題太散，遲遲沒有開始寫。",
                completionNote: "先用十分鐘列出想知道的事，再刪成六題；沒有從第一題就要求順序完美，反而很快完成。",
                chatSummary: "使用者擔心訪談問題太散，因此想在動筆前先排出完美順序。AI 注意到他先前用短時間建立骨架曾有效，建議先開十分鐘計時器，只列出所有想知道的事，時間到再刪減與排序。使用者接受這個方法，決定第一輪只求有內容，不在同時修改措辭。",
                wasHelpful: true, noHelpFeedback: nil
            ),
            DemoTask(
                day: 6, hour: 16, name: "整理下週課表與死線", category: "學校", subcategory: "規劃",
                complexity: 1, status: "done", progress: 1,
                note: "專題、經濟學作業和日文小考擠在同一週。",
                completionNote: "把三個死線放到同一頁後，先預留週二和週四晚上，焦慮感有比較下降。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            ),
            DemoTask(
                day: 6, hour: 21, name: "準備週一實習用品", category: "生活", subcategory: "準備",
                complexity: 0, status: "done", progress: 1,
                note: "識別證、筆電、充電器、水壺和雨傘。",
                completionNote: "照清單放進包包，早上不用再邊找東西邊趕車。",
                chatSummary: nil, wasHelpful: nil, noHelpFeedback: nil
            )
        ]

        for (index, item) in tasks.enumerated() {
            let task = TodoTask(name: item.name)
            task.category = item.category
            task.subcategory = item.subcategory
            task.complexity = item.complexity
            task.status = item.status
            task.progress = item.progress
            task.note = item.note
            task.startDate = timestamp(day: item.day, hour: item.hour)
            task.createdAt = task.startDate ?? timestamp(day: item.day, hour: item.hour)
            task.sortOrder = index
            context.insert(task)

            if let summary = item.chatSummary {
                let log = TaskLog(taskID: task.id, type: "chatSummary", content: summary)
                log.timestamp = timestamp(day: item.day, hour: item.hour, minute: 10)
                context.insert(log)
            }

            if item.wasHelpful == true {
                let log = TaskLog(
                    taskID: task.id,
                    type: "chatHelpful",
                    content: "使用者標記這次卡關解套有幫助，並依照對話中的下一步重新開始任務。"
                )
                log.timestamp = timestamp(day: item.day, hour: item.hour, minute: 18)
                context.insert(log)
            }

            if let feedback = item.noHelpFeedback {
                let log = TaskLog(taskID: task.id, type: "noHelpFeedback", content: feedback)
                log.timestamp = timestamp(day: item.day, hour: item.hour, minute: 18)
                context.insert(log)
            }

            if let completion = item.completionNote {
                let log = TaskLog(taskID: task.id, type: "completion", content: completion)
                log.timestamp = timestamp(day: item.day, hour: min(item.hour + 1, 23), minute: 5)
                context.insert(log)
            }
        }

        // MARK: Previous-week daily snapshots

        let dailySnapshots: [(wool: Int, starts: Int, stuck: Int, done: Int)] = [
            (187, 3, 0, 2),
            (323, 3, 1, 3),
            (320, 3, 1, 3),
            (216, 3, 1, 1),
            (323, 3, 1, 3),
            (320, 3, 1, 3),
            (169, 2, 0, 2),
        ]

        for (day, snapshot) in dailySnapshots.enumerated() {
            let stat = DailyStat(date: timestamp(day: day, hour: 0))
            stat.woolG = snapshot.wool
            stat.startCount = snapshot.starts
            stat.stuckCount = snapshot.stuck
            stat.doneCount = snapshot.done
            stat.isClosed = true
            stat.harvested = true
            context.insert(stat)
        }

        // Keep today empty. The value-demo opening creates its hero task through the
        // "AI 幫你建立" route, so the generated result is the task used by the rest of the flow.
        let todayStat = DailyStat(date: today)
        context.insert(todayStat)

        resetDemoAlpacaState(for: today, calendar: calendar)

        try? context.save()
        print("🌱 SeedData loaded: 20 previous-week tasks; today is ready for AI creation")
    }

    private static func resetDemoAlpacaState(for date: Date, calendar: Calendar) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(formatter.string(from: date), forKey: "alpaca.grantDay")
        UserDefaults.standard.set(0, forKey: "alpaca.grantCount")

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let rewardKey = "reward.alpacaGrowthTier.\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        UserDefaults.standard.set(0, forKey: rewardKey)
    }
}
