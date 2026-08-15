//
//  Theme.swift
//  AlpacaTest_kiki
//
//  Colors, type scale, and the unified modal template (COM-06). Owned by A.
//

import SwiftUI

// MARK: - Soft illustrated productivity theme

extension Color {
    static let alpacaCream       = Theme.background
    static let alpacaBeige       = Theme.surfaceMint
    static let alpacaBrown       = Theme.primaryText
    static let alpacaTerracotta  = Theme.primary
    static let alpacaOrange      = Theme.surfaceLeaf
    static let alpacaStuck       = Theme.surfaceLavender
    static let alpacaGreen       = Theme.surfaceLeaf
}

// MARK: - Type scale

extension Font {
    static let alpacaTitle   = Font.system(.title, design: .rounded).weight(.bold)
    static let alpacaHeading = Font.system(.headline, design: .rounded).weight(.semibold)
    static let alpacaBody    = Font.system(.body, design: .rounded)
    static let alpacaCaption = Font.system(.caption, design: .rounded)
}

enum Theme {
    static let background = Color(red: 0.945, green: 0.965, blue: 0.961)       // #F1F6F5
    static let primary = Color(red: 0.541, green: 0.808, blue: 0.780)          // #8ACEC7
    static let surfaceMint = Color(red: 0.753, green: 0.890, blue: 0.878)      // #C0E3E0
    static let surfaceLavender = Color(red: 0.729, green: 0.718, blue: 0.804)  // #BAB7CD
    static let surfaceLeaf = Color(red: 0.757, green: 0.816, blue: 0.561)      // #C1D08F
    static let highlight = Color(red: 0.702, green: 0.914, blue: 0.031)        // #B3E908
    static let primaryText = Color(red: 0.184, green: 0.216, blue: 0.208)      // #2F3735
    static let secondaryText = Color(red: 0.384, green: 0.424, blue: 0.412)    // #626C69
    static let tertiaryText = Color(red: 0.573, green: 0.608, blue: 0.596)     // #929B98

    static let cardCornerRadius: CGFloat = 28
    static let cardRadius: CGFloat = 28
    static let smallRadius: CGFloat = 18
    static let modalCornerRadius: CGFloat = 28
    static let sectionTitleFont = Font.system(.headline, design: .rounded).weight(.semibold)
}

extension View {
    func softFeedbackCard(surface: Color = .white.opacity(0.62)) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: Theme.primaryText.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Modal template (COM-06)

/// A single modal button description used by ConfirmModal.
struct ModalAction {
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
}

/// The unified confirm/success/failure modal (COM-06).
/// Every confirm/success/failure modal in the app (TOD-04/05, STK-01/03, SPL-03/04,
/// TSK-06, HOME-04/05/06, EOD-06) uses THIS template with different copy — no bespoke modals.
struct ConfirmModal: View {
    let title: String
    let message: String
    let primary: ModalAction
    var secondary: ModalAction?

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.alpacaHeading)
                .foregroundStyle(Color.alpacaBrown)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.alpacaBody)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: primary.action) {
                    Text(primary.title)
                        .font(.alpacaHeading)
                        .foregroundStyle(Theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(primary.isDestructive ? Theme.surfaceLavender : Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                }

                if let secondary {
                    Button(action: secondary.action) {
                        Text(secondary.title)
                            .font(.alpacaBody)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.alpacaCream)
        .clipShape(RoundedRectangle(cornerRadius: Theme.modalCornerRadius))
        .shadow(radius: 20)
        .padding(32)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        ConfirmModal(
            title: "這個任務有點大嗎？",
            message: "要不要拆成幾個小步驟，讓它更好開始？",
            primary: ModalAction(title: "幫我拆解") {},
            secondary: ModalAction(title: "先不用，直接開始") {}
        )
    }
}
