//
//  RewardEngine.swift
//  AlpacaTest_kiki
//
//  Wool reward rules (TEAM_PLAN §1.4). Owned by B — the SOLE entry point for adding wool.
//  A/C only call grant(); never add wool anywhere else.
//

import Foundation
import SwiftData

enum RewardEvent {
    case startTask(Int)       // complexity 0 easy / 1 medium / 2 hard
    case startSubtask
    case acceptSplit
    case stuckHelpAccepted
    case stuckHelpRejectedWithFeedback
    case stuckHelpRejectedWithoutFeedback
    case complete(Int)        // complexity 0 easy / 1 medium / 2 hard
    case completionNoteBonus
}

enum RewardEngine {
    // 單次行為獲得的羊毛克數只存在後台；顯示時由回饋／結算頁讀取 DailyStat.woolG。
    static func woolFor(_ event: RewardEvent) -> Int {
        switch event {
        case .startTask(let complexity):
            return woolForStartingTask(complexity: complexity)
        case .startSubtask:
            return 15
        case .acceptSplit:
            return 12
        case .stuckHelpAccepted, .stuckHelpRejectedWithFeedback:
            return 60
        case .stuckHelpRejectedWithoutFeedback:
            return 39
        case .complete:
            return 41
        case .completionNoteBonus:
            return 19
        }
    }

    // 任務複雜度：0 簡單 18g / 1 中等 31g / 2 困難 47g；其他值保守視為中等。
    private static func woolForStartingTask(complexity: Int) -> Int {
        switch complexity {
        case 0: return 18
        case 2: return 47
        default: return 31
        }
    }

    /// Sole entry point: adds to today's DailyStat.woolG and posts .woolGained (alpaca fluff animation).
    static func grant(_ event: RewardEvent, context: ModelContext) {
        let grams = woolFor(event)
        let stat = todayStat(context: context)
        stat.woolG += grams

        switch event {
        case .startTask, .startSubtask:
            stat.startCount += 1
        case .stuckHelpAccepted, .stuckHelpRejectedWithFeedback, .stuckHelpRejectedWithoutFeedback:
            stat.stuckCount += 1
        case .complete:
            stat.doneCount += 1
        case .acceptSplit, .completionNoteBonus:
            break
        }

        try? context.save()
        NotificationCenter.default.post(name: .woolGained, object: nil,
                                        userInfo: ["grams": grams, "totalToday": stat.woolG])
    }

    /// Fetches today's DailyStat, creating one if the day hasn't been opened yet.
    private static func todayStat(context: ModelContext) -> DailyStat {
        let all = (try? context.fetch(FetchDescriptor<DailyStat>())) ?? []
        if let existing = all.first(where: { Calendar.current.isDateInToday($0.date) && !$0.isClosed }) {
            return existing
        }
        let fresh = DailyStat(date: Date())
        context.insert(fresh)
        return fresh
    }
}
