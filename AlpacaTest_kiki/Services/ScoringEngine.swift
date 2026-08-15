//
//  ScoringEngine.swift
//  [C 擁有 — 明天複製到 repo 的 Services/ScoringEngine.swift]
//
//  從歷史任務中挑出跟「目前卡住的任務」最相關的 3–5 筆，餵給 AI 當記憶
//  （對應設計師 prompt 的 RELATED_HISTORICAL_TASKS：AI 不重新計分，計分在這裡做完）。
//  公式依 TEAM_PLAN：分類 40/20、時間 30/20/10、品質 20+10、門檻 ≥40、
//  取 3–5 筆、不足走冷啟動。數字可調，demo 前跟 prompt 一起打磨。
//

import Foundation
import SwiftData

enum ScoringEngine {

    /// 主入口：View 只要傳目前任務 + modelContext
    static func relevantHistory(for task: TodoTask, context: ModelContext) -> [HistoricalTaskSummary] {
        let allTasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
        let allLogs = (try? context.fetch(FetchDescriptor<TaskLog>())) ?? []
        return pick(for: task, from: allTasks, logs: allLogs)
    }

    /// 可測試的純函式版本（不碰資料庫）
    static func pick(for task: TodoTask, from allTasks: [TodoTask],
                     logs: [TaskLog], today: Date = .now) -> [HistoricalTaskSummary] {

        let calendar = Calendar.current
        let candidates = allTasks.filter { $0.id != task.id && $0.status == "done" }

        var scored: [HistoricalTaskSummary] = candidates.compactMap { old in
            let refDate = old.startDate ?? old.createdAt
            let daysAgo = max(0, calendar.dateComponents([.day], from: refDate, to: today).day ?? 999)
            guard daysAgo <= 30 else { return nil }          // 只看 30 天內

            let oldLogs = logs.filter { $0.taskID == old.id }
            let completionNote = oldLogs.last { $0.type == "completion" }?.content
            let hadStuckHelp = oldLogs.contains { $0.type == "chatSummary" }

            var score = 0
            // 分類 40/20：同分類 40；同子分類再 +20
            if let c = task.category, c == old.category { score += 40 }
            if let s = task.subcategory, s == old.subcategory { score += 20 }
            // 時間 30/20/10：越近越相關
            if daysAgo <= 7 { score += 30 }
            else if daysAgo <= 14 { score += 20 }
            else { score += 10 }
            // 品質 20+10：有完成備註 +20；有卡關記錄 +10（有可引用的脈絡）
            if completionNote?.isEmpty == false { score += 20 }
            if hadStuckHelp { score += 10 }

            return HistoricalTaskSummary(name: old.name, category: old.category,
                                         daysAgo: daysAgo, hadStuckHelp: hadStuckHelp,
                                         completionNote: completionNote, score: score)
        }

        scored.sort { $0.score > $1.score }
        let qualified = scored.filter { $0.score >= 40 }

        if qualified.count >= 3 {
            return Array(qualified.prefix(5))                // 正常路徑：取 3–5 筆
        }
        return Array(scored.prefix(3))                       // 冷啟動：給最相關的最多 3 筆
    }
}
