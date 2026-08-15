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

    /// 當日發放次數，跨 view 重建（切分頁、關 sheet）都要留著，
    /// 否則羊駝會被打回光溜溜的 alpaca_0。
    @AppStorage("alpaca.grantDay")   private var storedDay: String = ""
    @AppStorage("alpaca.grantCount") private var storedCount: Int = 0

    @State private var tier: Int = 0
    @State private var isBlinking = false

    private static let maxTier = 3
    private static let blinkAssetName = "(("

    /// 當天的 key。用本地日曆，跟 TodayView 的當日區間同一套時區觀念。
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

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

            // 閉眼圖片只疊在羊駝上方短暫出現，製造 blink 效果。
            blinkOverlay
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
        .task { await runBlinkLoop() }
        .onAppear { syncTier() }
        .onReceive(NotificationCenter.default.publisher(for: .woolGained)) { _ in
            registerGrant()
        }
        // 收割後 / 跨日：新開的工作日 woolG 是 0 → 羊駝歸零
        .onChange(of: openTodayWoolG) { _, wool in
            if wool == 0 { resetTier() }
        }
    }

    // MARK: - Tier state

    /// 進畫面時把 tier 對回持久化的次數。
    /// 跨日、或這個工作日還沒發過羊毛（含剛收割完新開的那筆）都歸零。
    private func syncTier() {
        if storedDay != todayKey {
            storedDay = todayKey
            storedCount = 0
        }
        if openTodayWoolG == 0 {
            storedCount = 0
        }

        tier = min(storedCount, Self.maxTier)
    }

    /// 每收到一次 .woolGained 就升一階（上限 3）
    private func registerGrant() {
        if storedDay != todayKey {          // 跨日的第一次發放
            storedDay = todayKey
            storedCount = 0
        }

        storedCount += 1
        let newTier = min(storedCount, Self.maxTier)
        guard newTier != tier else { return }

        withAnimation(.easeInOut(duration: 0.40)) {
            tier = newTier
        }
    }

    private func resetTier() {
        storedCount = 0
        withAnimation(.easeInOut(duration: 0.40)) {
            tier = 0
        }
    }

    // MARK: - Blink animation

    // 閉眼圖大小：四張羊駝的眼睛位置一致時，只需要調這個固定寬度。
    // 數字變大 = 閉眼圖變大；數字變小 = 閉眼圖變小。
    private var blinkWidth: CGFloat { 22 }

    // 閉眼圖左右位置：正數往右，負數往左。
    private var blinkXOffset: CGFloat { -19.5 }

    // 閉眼圖上下位置：正數往下，負數往上。
    private var blinkYOffset: CGFloat { -46 }

    @ViewBuilder
    private var blinkOverlay: some View {
        if UIImage(named: Self.blinkAssetName) != nil {
            Image(Self.blinkAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: blinkWidth)
                .offset(x: blinkXOffset, y: blinkYOffset)
                .opacity(isBlinking ? 1:0)
                .animation(.easeInOut(duration: 0.05), value: isBlinking)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func runBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isBlinking = true
            }

            try? await Task.sleep(for: .seconds(0.12))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isBlinking = false
            }
        }
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
        let name = "alpaca_\(min(max(tier, 0), maxTier))"
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
