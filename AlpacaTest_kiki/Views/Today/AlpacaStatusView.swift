//
//  AlpacaStatusView.swift
//  AlpacaTest_kiki
//
//  The alpaca on the Today screen (COM-08). Owned by A.
//
//  ★ STATE-09 IRON LAW ★
//  Image only. No gram counts. No captions. No numbers of any kind.
//
//  分階規則（Demo 版，設計師指定）：**每次發羊毛就升一階**，不是看公克數門檻。
//  Demo 的總量根本到不了公克門檻，逐次升階才看得出獎勵。
//    tier = min(今天的發放次數, 3) → alpaca_0…alpaca_3
//
//  為什麼用 @AppStorage 而不是 DailyStat 的計數器：
//    RewardEngine 只有 startCount / stuckCount / doneCount，
//    `.acceptSplit` 和 `.completionNoteBonus` 兩種事件是 `break`，不加任何計數。
//    用那三個欄位相加會漏掉「接受拆分」——而那正好是 Demo 腳本第 3 步，
//    羊駝會在最關鍵的時候不動。乾淨的長期解是在 DailyStat 加一個 grantCount，
//    但那是 B 的檔案，需要先講好。在那之前這裡自己存一份當日計數。
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AlpacaStatusView: View {
    @Query(sort: \DailyStat.date) private var allStats: [DailyStat]

    @State private var tier: Int = 0

    /// 今天「還開著」的那一筆 DailyStat。
    /// 一定要帶 !isClosed：收割後 EODFlow 會把舊的那筆設成 harvested+isClosed，
    /// 然後**再插入一筆今天的新 DailyStat**（openActiveWorkdayIfNeeded）。
    /// 只比日期的話同一天會有兩筆、抓到哪一筆不確定。這裡跟 RewardEngine 用同一條規則。
    private var openTodayStat: DailyStat? {
        allStats.first { Calendar.current.isDateInToday($0.date) && !$0.isClosed }
    }

    /// 當前這個工作日已經累積的羊毛。
    /// 收割後新開的那一筆是 0，跨日新開的也是 0 —— 兩種情況羊駝都該回到第 0 階，
    /// 所以「開著的那筆 woolG == 0」就是唯一的歸零條件，不必去猜 harvested 旗標。
    private var openTodayWoolG: Int {
        openTodayStat?.woolG ?? 0
    }

    var body: some View {
        ZStack {
            alpaca
                .id(tier)                    // 換階 → 移除＋插入 → 淡入淡出
                .transition(.opacity)
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        // 彈一下才有「拿到獎勵」的感覺。keyframeAnimator 由 tier 觸發，
        // 連續發放時會直接重跑而不是排隊，所以不會抖。
        .keyframeAnimator(initialValue: 1.0, trigger: tier) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.08, duration: 0.18, spring: .snappy)
                SpringKeyframe(1.0,  duration: 0.30, spring: .bouncy)
            }
        }
        .accessibilityLabel("羊駝狀態")        // 連 VoiceOver 都不講公克數
        .onAppear { syncTier() }
        // RewardEngine 每次發放都會把新的 growthTier 一起送出來，直接用它，
        // 不要自己另外數一份（回饋頁也是讀這個值）。
        .onReceive(NotificationCenter.default.publisher(for: .woolGained)) { notification in
            let posted = notification.userInfo?["growthTier"] as? Int
            applyTier(posted ?? RewardEngine.alpacaGrowthTier())
        }
        // 收割後 / 跨日：新開的工作日 woolG 是 0 → 羊駝歸零
        .onChange(of: openTodayWoolG) { _, wool in
            if wool == 0 { resetTier() }
        }
    }

    // MARK: - Tier state

    /// 進畫面時對回 RewardEngine 記的成長次數。
    /// 這個工作日還沒發過羊毛（含剛收割完新開的那一筆）就顯示第 0 階。
    private func syncTier() {
        tier = openTodayWoolG == 0 ? 0 : RewardEngine.alpacaGrowthTier()
    }

    private func applyTier(_ newTier: Int) {
        guard newTier != tier else { return }
        withAnimation(.easeInOut(duration: 0.40)) {
            tier = newTier
        }
    }

    private func resetTier() {
        applyTier(0)
    }

    // MARK: - Artwork

    /// 用資產目錄裡的 alpaca_0…3；圖還沒進來時退回一個看得出變化的 placeholder。
    @ViewBuilder
    private var alpaca: some View {
        if let artwork = Self.artworkName(for: tier) {
            Image(artwork)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: placeholderSize, height: placeholderSize)
                .foregroundStyle(Color.alpacaOrange.opacity(placeholderOpacity))
        }
    }

    private static func artworkName(for tier: Int) -> String? {
        let name = "alpaca_\(min(max(tier, 0), 3))"
        #if canImport(UIKit)
        return UIImage(named: name) == nil ? nil : name
        #else
        return nil
        #endif
    }

    private var placeholderSize: CGFloat {
        switch tier {
        case 0:  return 96
        case 1:  return 116
        case 2:  return 136
        default: return 156
        }
    }

    private var placeholderOpacity: Double {
        switch tier {
        case 0:  return 0.55
        case 1:  return 0.70
        case 2:  return 0.85
        default: return 1.0
        }
    }
}

#Preview {
    AlpacaStatusView()
        .background(Color.alpacaCream)
        .modelContainer(for: [TodoTask.self, DailyStat.self], inMemory: true)
}
