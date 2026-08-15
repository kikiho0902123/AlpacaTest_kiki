//
//  EODRequest.swift
//  AlpacaTest_kiki
//
//  Sheet payload for B's end-of-day flow (EOD-01/02), presented from TodayView.
//  Extracted from TodayView so the Today screen file holds views only.
//  Authored by B; moved here by A during Step 2.
//

import Foundation

struct EODRequest: Identifiable {
    let id = UUID()
    let date: Date
    let isAutoRollover: Bool
}
