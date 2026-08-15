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

/// 拆分流程的 sheet payload。由 TodayView 持有 —— 任務卡在拆分成功後
/// 會換區塊而被銷毀，不能由它自己 present（SPL-04 會提早消失）。
struct SplitRequest: Identifiable {
    let id = UUID()
    let task: TodoTask
    let source: SplitSource
}
