//
//  AlpacaStatusView.swift
//  AlpacaTest_kiki
//
//  The alpaca on the Today screen (COM-08). Owned by A.
//
//  ★ STATE-09 IRON LAW ★
//  Image only. No gram counts. No captions. No numbers of any kind.
//  The fluff tier is derived from today's woolG, but that mapping lives ONLY in
//  code — the number itself is never rendered anywhere on this screen. Grams are
//  first revealed in B's achievement modal at end of day.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AlpacaStatusView: View {
    @Query(sort: \DailyStat.date) private var allStats: [DailyStat]

    @State private var tier: Int = 0

    /// Fluff tiers. Thresholds are deliberately code-only (STATE-09).
    private static let tierThresholds: [Int] = [300, 800, 1500]

    private static func tier(forWoolG woolG: Int) -> Int {
        var tier = 0
        for threshold in tierThresholds where woolG >= threshold {
            tier += 1
        }
        return tier
    }

    /// Today's open DailyStat, matching RewardEngine's own lookup rule.
    private var todayWoolG: Int {
        allStats.first {
            Calendar.current.isDateInToday($0.date) && !$0.isClosed
        }?.woolG ?? 0
    }

    var body: some View {
        alpaca
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .id(tier)                       // tier change → remove + insert → crossfade
            .transition(.opacity)
            .accessibilityLabel("羊駝狀態")  // no grams, even to VoiceOver
            .onAppear {
                tier = Self.tier(forWoolG: todayWoolG)
            }
            .onReceive(NotificationCenter.default.publisher(for: .woolGained)) { notification in
                let total = notification.userInfo?["totalToday"] as? Int ?? todayWoolG
                withAnimation(.easeInOut(duration: 0.45)) {
                    tier = Self.tier(forWoolG: total)
                }
            }
    }

    // MARK: - Artwork

    /// Uses `alpaca_0…3` from the asset catalogue once B's art lands; until then a
    /// placeholder that still visibly fluffs up, so the animation is demoable today.
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
        let name = "alpaca_\(tier)"
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
