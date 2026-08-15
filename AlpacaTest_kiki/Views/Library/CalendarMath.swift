//
//  CalendarMath.swift
//  AlpacaTest_kiki
//
//  月曆格子的日期運算（LIB-T01）。Owned by A.
//
//  ★ 時區規則：一律用 Calendar.current 的 startOfDay 當界線、區間一律半開
//    [start, end)。這跟 TodayView.todayPredicate() 是同一套；日期存的是 UTC，
//    自己另外發明換算方式會讓所有任務整批偏一天。
//

import Foundation

enum CalendarMath {

    /// 跟 TodayView 用同一個 Calendar.current（時區正確），只把一週起始固定成週日，
    /// 對應設計稿的「日一二三四五六」。firstWeekday 不影響 startOfDay。
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1        // Sunday
        return calendar
    }

    static let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    /// 某個月的一號 00:00（本地）
    static func startOfMonth(for date: Date) -> Date {
        let calendar = calendar
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// 「2026年8月」
    static func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    /// 「8月15日 星期六」——單日總覽標題用
    static func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    /// 補滿整週的格子：從包含一號的那一週的週日開始，到補滿最後一週為止。
    static func gridDays(for monthAnchor: Date) -> [Date] {
        let calendar = calendar
        let monthStart = startOfMonth(for: monthAnchor)

        // 一號是星期幾（1 = 週日）→ 前面要補幾格
        let leading = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        let normalizedLeading = (leading + 7) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -normalizedLeading, to: monthStart),
              let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count
        else { return [] }

        let totalCells = Int((Double(normalizedLeading + dayCount) / 7.0).rounded(.up)) * 7

        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    /// 這個月格子涵蓋的整體區間（含前後月補齊的日子），給 @Query 用。
    /// 半開區間，跟 TodayView 一致。
    static func visibleRange(for monthAnchor: Date) -> (start: Date, end: Date) {
        let days = gridDays(for: monthAnchor)
        guard let first = days.first, let last = days.last else {
            let fallback = startOfMonth(for: monthAnchor)
            return (fallback, fallback)
        }

        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return (first, end)
    }

    /// 單日的半開區間 [當天 00:00, 隔天 00:00)
    static func dayRange(for date: Date) -> (start: Date, end: Date) {
        let calendar = calendar
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    static func isSameMonth(_ date: Date, as other: Date) -> Bool {
        calendar.isDate(date, equalTo: other, toGranularity: .month)
    }
}
