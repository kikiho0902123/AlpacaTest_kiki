//
//  TaskItem.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import Foundation
import SwiftData

// 任務複雜程度（電量圖示：易中難）
enum TaskDifficulty: Int, Codable, CaseIterable, Identifiable {
    case easy = 1
    case medium = 2
    case hard = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .easy: return "簡單"
        case .medium: return "中等"
        case .hard: return "困難"
        }
    }

    // 用電量圖示代表複雜程度
    var batteryIcon: String {
        switch self {
        case .easy: return "battery.25"
        case .medium: return "battery.50"
        case .hard: return "battery.100"
        }
    }
}

@Model
final class TaskItem {
    var id: UUID
    var name: String
    var isMustDoToday: Bool      // 閃電圖示：今日一定要完成
    var difficultyRaw: Int       // 儲存用，實際用 difficulty 存取
    var progress: Double         // 0.0 ~ 1.0，使用者手動拖拉回報完成度
    var isCompleted: Bool
    var isStuck: Bool            // 卡住了狀態
    var isStarted: Bool          // 是否已按下開始
    var createdAt: Date
    var completedAt: Date?

    var difficulty: TaskDifficulty {
        get { TaskDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }

    init(name: String, isMustDoToday: Bool = false, difficulty: TaskDifficulty = .easy) {
        self.id = UUID()
        self.name = name
        self.isMustDoToday = isMustDoToday
        self.difficultyRaw = difficulty.rawValue
        self.progress = 0
        self.isCompleted = false
        self.isStuck = false
        self.isStarted = false
        self.createdAt = Date()
        self.completedAt = nil
    }
}
