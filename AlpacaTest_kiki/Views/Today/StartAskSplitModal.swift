//
//  StartAskSplitModal.swift
//  AlpacaTest_kiki
//
//  TOD-04「開始任務 — 這是大型任務嗎？要拆分嗎？」Owned by A.
//
//  用共用的 ConfirmModal 樣板（COM-06），不做客製 modal。
//  「否」→ 呼叫端照 Step 1 的方式直接開始；「是」→ C 的 SplitFlowModal(source: .startAsk)。
//  呼叫方式：.fullScreenCover { StartAskSplitModal(...).presentationBackground(.clear) }
//

import SwiftUI

struct StartAskSplitModal: View {
    /// 「是」→ 交給 C 的拆分流程（source: .startAsk）
    let onSplit: () -> Void
    /// 「否」→ 直接開始任務（status=started, progress=0.2, grant）
    let onStartDirectly: () -> Void

    var body: some View {
        DimmedModal {
            ConfirmModal(
                title: "這是大型任務嗎？",
                message: "是否進行拆分？拆成幾個小步驟會更好開始。",
                primary: ModalAction(title: "是，幫我拆解", action: onSplit),
                secondary: ModalAction(title: "否，直接開始", action: onStartDirectly)
            )
        }
    }
}

#Preview {
    StartAskSplitModal(onSplit: {}, onStartDirectly: {})
}
