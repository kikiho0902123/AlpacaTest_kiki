//
//  CategoryColor.swift
//  AlpacaTest_kiki
//
//  分類配色（TSK-03）。Owned by A.
//  新分類建立時從固定調色盤依序取一個色，寫進 TodoTask.colorHex。
//  舊資料沒有 colorHex 的，卡片會用 stableHex(for:) 依分類名稱回推同一個色，
//  所以不用回頭編輯每一筆也能看到不同顏色的色條。
//

import SwiftUI

enum CategoryColor {

    /// 固定調色盤。刻意跟 Theme 的柔和色系一致，但彼此色相要拉開。
    static let paletteHex: [String] = [
        "#8ACEC7",   // mint
        "#C1D08F",   // leaf
        "#BAB7CD",   // lavender
        "#E8A87C",   // apricot
        "#8FB8DE",   // sky
        "#D9A5C0"    // rose
    ]

    /// 建立新分類時用：照現有分類數量循環取色。
    static func hex(atIndex index: Int) -> String {
        paletteHex[((index % paletteHex.count) + paletteHex.count) % paletteHex.count]
    }

    /// 舊資料（colorHex == nil）的回推色：依分類名稱穩定對應。
    /// 不用 hashValue —— 它每次啟動的種子不同，顏色會跳。
    static func stableHex(for category: String) -> String {
        let sum = category.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return hex(atIndex: sum)
    }

    /// 卡片／清單顯示用：優先用任務自己的 colorHex，其次依分類回推，都沒有才用預設強調色。
    static func color(colorHex: String?, category: String?) -> Color {
        if let colorHex, let parsed = Color(hex: colorHex) { return parsed }
        if let category, let parsed = Color(hex: stableHex(for: category)) { return parsed }
        return .alpacaTerracotta
    }
}
