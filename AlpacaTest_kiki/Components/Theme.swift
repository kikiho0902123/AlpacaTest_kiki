//
//  Theme.swift
//  AlpacaTest_kiki
//
//  Colors, type scale, and the unified modal template (COM-06). Owned by A.
//

import SwiftUI

// MARK: - 溫暖羊駝主題色系

extension Color {
    static let alpacaCream       = Color(red: 0.98, green: 0.93, blue: 0.85) // 背景奶油色
    static let alpacaBeige       = Color(red: 0.94, green: 0.85, blue: 0.72) // 卡片邊框米色
    static let alpacaBrown       = Color(red: 0.45, green: 0.32, blue: 0.22) // 主要文字深咖啡色
    static let alpacaTerracotta  = Color(red: 0.85, green: 0.45, blue: 0.28) // 主色調赤陶橘
    static let alpacaOrange      = Color(red: 0.93, green: 0.58, blue: 0.30) // 強調橘
    static let alpacaStuck       = Color(red: 0.86, green: 0.35, blue: 0.30) // 卡住了警示紅橘
    static let alpacaGreen       = Color(red: 0.55, green: 0.68, blue: 0.45) // 完成綠
}

// MARK: - Type scale

extension Font {
    static let alpacaTitle   = Font.system(.title, design: .rounded).weight(.bold)
    static let alpacaHeading = Font.system(.headline, design: .rounded).weight(.semibold)
    static let alpacaBody    = Font.system(.body, design: .rounded)
    static let alpacaCaption = Font.system(.caption, design: .rounded)
}

enum Theme {
    static let cardCornerRadius: CGFloat = 20
    static let modalCornerRadius: CGFloat = 24
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
                .foregroundStyle(Color.alpacaBrown.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: primary.action) {
                    Text(primary.title)
                        .font(.alpacaHeading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(primary.isDestructive ? Color.alpacaStuck : Color.alpacaTerracotta)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let secondary {
                    Button(action: secondary.action) {
                        Text(secondary.title)
                            .font(.alpacaBody)
                            .foregroundStyle(Color.alpacaBrown.opacity(0.7))
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
