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
    case startTask
    case startSubtask
    case acceptSplit
    case stuckChatDone
    case complete(Int)        // complexity 0 easy / 1 medium / 2 hard
    case completionNoteBonus
}

enum RewardEngine {
    // Spec fixes only 15g per subtask start (SPL-06); the rest are provisional, tunable pre-demo
    static func woolFor(_ event: RewardEvent) -> Int {
        switch event {
        case .startTask:            return 50
        case .startSubtask:         return 15          // fixed by spec
        case .acceptSplit:          return 30
        case .stuckChatDone:        return 40
        case .complete(let cx):     return [100, 200, 300][min(max(cx, 0), 2)]   // easy/medium/hard
        case .completionNoteBonus:  return 50          // TOD-06: extra reward when a note is written
        }
    }

    /// Sole entry point: adds to today's DailyStat.woolG and posts .woolGained (alpaca fluff animation).
    static func grant(_ event: RewardEvent, context: ModelContext) {
        let grams = woolFor(event)
        let stat = todayStat(context: context)
        stat.woolG += grams

        switch event {
        case .startTask, .startSubtask: stat.startCount += 1
        case .stuckChatDone:            stat.stuckCount += 1
        case .complete:                 stat.doneCount += 1
        case .acceptSplit, .completionNoteBonus: break
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
