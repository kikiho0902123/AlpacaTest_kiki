//
//  AppEvents.swift
//  AlpacaTest_kiki
//
//  Cross-screen events (TEAM_PLAN §1.6). Changing one requires all three to agree.
//

import Foundation

extension Notification.Name {
    static let woolGained    = Notification.Name("woolGained")    // A listens: alpaca fluff animation (COM-08)
    static let taskCompleted = Notification.Name("taskCompleted") // B listens: completion flow
    static let taskSplit     = Notification.Name("taskSplit")     // A listens: home refresh insurance
    static let dayEnded      = Notification.Name("dayEnded")      // B listens: EOD flow
}
