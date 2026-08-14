//
//  SharedComponents.swift
//  AlpacaTest_kiki
//
//  Reusable UI pieces shared across tracks (TEAM_PLAN §1.2). Owned by A.
//

import SwiftUI

/// Simple progress bar used by task cards (COM-02).
struct ProgressBarView: View {
    var progress: Double            // 0.0 ... 1.0
    var isDone: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.alpacaBeige.opacity(0.5))
                Capsule()
                    .fill(isDone ? Color.alpacaGreen : Color.alpacaTerracotta)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

/// Complexity "battery" indicator. complexity: 0 easy / 1 medium / 2 hard.
struct ComplexityBattery: View {
    var complexity: Int

    private var iconName: String {
        switch complexity {
        case 0:  return "battery.25"
        case 1:  return "battery.50"
        default: return "battery.100"
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(Color.alpacaBrown.opacity(0.7))
            .accessibilityLabel("複雜程度")
    }
}

/// Category / subcategory tag chip.
struct TagChip: View {
    var text: String
    var color: Color = .alpacaOrange

    var body: some View {
        Text(text)
            .font(.alpacaCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBarView(progress: 0.4)
        ComplexityBattery(complexity: 2)
        TagChip(text: "學習")
    }
    .padding()
    .background(Color.alpacaCream)
}
