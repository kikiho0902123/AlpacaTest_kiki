//
//  ParsedTaskPlaceholder.swift
//  AlpacaTest_kiki
//
//  ⚠️⚠️ 暫時檔案 —— C 的 AIService.parseTask(_:) 一進 repo 就整個刪掉 ⚠️⚠️
//
//  C 還沒推 parseTask/ParsedTask，這裡先用同樣的簽名頂著，讓 UI 這條線可以先做完並編譯。
//  刻意寫成 AIService 的 extension，這樣呼叫端 `AIService.shared.parseTask(text)`
//  跟 C 的正式版一模一樣 —— 到時候只要刪掉這個檔案，其他地方一行都不用改。
//
//  ★ 刪除時機：C 的版本一 merge 進來就刪。
//    同一個 module 裡有兩份 ParsedTask / parseTask 會直接 redeclaration 編譯失敗
//    （跟先前 Color(hex:) 撞在一起是同一種狀況）。
//
//  ★ 欄位形狀是猜的：C_INTERFACES.md 目前沒有定義 ParsedTask。
//    等 C 的版本進來，如果欄位名稱不同，要改的是 AITaskCreationView 裡
//    ParsedTask → TaskEditorView(prefill:) 那一段對應。
//

import Foundation

/// AI 從一段自然語言解析出來的任務草稿。使用者一定會先看到、確認後才寫進資料庫。
struct ParsedTask {
    var name: String
    var category: String?
    var subcategory: String?
    var note: String?
    var startDate: Date?
    var isUrgent: Bool = false
    var isMustToday: Bool = false
    var complexity: Int = 1        // 0 easy / 1 medium / 2 hard
}

extension AIService {

    /// 暫時的假解析：不呼叫任何 API，用關鍵字湊出一份草稿。
    /// C 的正式版會換掉整個實作，簽名維持一樣。
    func parseTask(_ text: String) async throws -> ParsedTask {
        try? await Task.sleep(nanoseconds: 900_000_000)   // 假裝在想

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ParsedTaskPlaceholderError.emptyInput
        }

        let calendar = Calendar.current
        var startDate: Date? = calendar.startOfDay(for: .now)
        var isUrgent = false
        var isMustToday = false

        if trimmed.contains("明天") {
            startDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        } else if trimmed.contains("下週") || trimmed.contains("下周") {
            startDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: .now))
        }

        if trimmed.contains("今天") {
            isMustToday = true
        }
        if trimmed.contains("急") || trimmed.contains("趕") || trimmed.contains("死線") {
            isUrgent = true
        }

        let complexity: Int
        if trimmed.contains("沒頭緒") || trimmed.contains("報告") || trimmed.contains("專題") {
            complexity = 2
        } else if trimmed.count > 20 {
            complexity = 1
        } else {
            complexity = 0
        }

        // 名稱取第一個句子，太長就截斷
        let firstSentence = trimmed
            .split(whereSeparator: { "，,。.!？?\n".contains($0) })
            .first
            .map(String.init) ?? trimmed
        let name = firstSentence.count > 24 ? String(firstSentence.prefix(24)) : firstSentence

        return ParsedTask(
            name: name,
            category: nil,
            subcategory: nil,
            note: trimmed == name ? nil : trimmed,
            startDate: startDate,
            isUrgent: isUrgent,
            isMustToday: isMustToday,
            complexity: complexity
        )
    }
}

enum ParsedTaskPlaceholderError: LocalizedError {
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "請先描述一下你的任務。"
        }
    }
}
