//
//  Models.swift
//  AlpacaTest_kiki
//
//  All @Model classes (TEAM_PLAN §1.3). Owned by A — new field → ask A.
//  Status strings are verbatim; do not invent values.
//

import SwiftData
import Foundation

@Model
final class TodoTask {
    var id: UUID = UUID()
    var name: String
    var category: String?
    var subcategory: String?
    var colorHex: String?
    // startDate 與 isUrgent 是獨立欄位：已排程任務也可以同時是緊急任務。
    var startDate: Date?
    var isUrgent: Bool = false
    var isMustToday: Bool = false
    var complexity: Int = 1              // 0 easy / 1 medium / 2 hard
    var note: String?
    var status: String = "notStarted"    // notStarted/started/split/done/archived
    var progress: Double = 0             // start → auto 0.2; 1.0 triggers completion flow (COM-02)
    var createdAt: Date = Date()
    var parentID: UUID?
    var sortOrder: Int = 0
    init(name: String) { self.name = name }
}

@Model
final class TaskLog {                    // STATE-08: start note / chat summary / completion note
    var id: UUID = UUID()
    var taskID: UUID
    var timestamp: Date = Date()
    var type: String                     // "startNote"/"chatSummary"/"completion"/"split"
    var content: String
    init(taskID: UUID, type: String, content: String) {
        self.taskID = taskID; self.type = type; self.content = content
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var taskID: UUID
    var sessionID: UUID                  // one stuck-help conversation = one session (round counting)
    var role: String                     // "user"/"assistant"
    var content: String
    var timestamp: Date = Date()
    init(taskID: UUID, sessionID: UUID, role: String, content: String) {
        self.taskID = taskID; self.sessionID = sessionID; self.role = role; self.content = content
    }
}

@Model
final class DailyStat {                  // one "subjective workday" (STATE-03)
    var date: Date                       // workday label
    var woolG: Int = 0                   // ★ grams. Accrues silently in the background (STATE-09)
    var startCount: Int = 0
    var stuckCount: Int = 0
    var doneCount: Int = 0
    var isClosed: Bool = false           // day ended (snapshot, STATE-04)
    var harvested: Bool = false
    init(date: Date) { self.date = date }
}

@Model
final class UserProfile {                // singleton. Onboarding not built; seeded with fake data
    var name: String = "Demo User"
    var woolBankG: Int = 0               // My Home wool bank (STATE-05)
    var gloveCount: Int = 0              // textile library (STATE-06)
    var scarfCount: Int = 0
    var capeCount: Int = 0
    var onboardingJSON: String = "{}"    // questionnaire answers; seeded fake, fed to prompts
    init() {}
}
