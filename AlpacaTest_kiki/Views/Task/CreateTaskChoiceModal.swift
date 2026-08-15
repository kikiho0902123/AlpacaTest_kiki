//
//  CreateTaskChoiceModal.swift
//  AlpacaTest_kiki
//
//  按「＋」之後先問要手動還是讓 AI 幫忙。Owned by A。
//  用共用的 ConfirmModal 樣板（COM-06），只是換字，不做客製 modal。
//

import SwiftUI

struct CreateTaskChoiceModal: View {
    let onAI: () -> Void
    let onManual: () -> Void

    var body: some View {
        DimmedModal {
            ConfirmModal(
                title: "要怎麼建立任務？",
                message: "可以自己填，也可以描述一下狀況讓 AI 幫你整理成任務。",
                primary: ModalAction(title: "AI 幫你建立", action: onAI),
                secondary: ModalAction(title: "手動建立", action: onManual)
            )
        }
    }
}

#Preview {
    CreateTaskChoiceModal(onAI: {}, onManual: {})
}
