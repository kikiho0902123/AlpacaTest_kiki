//
//  MyHomeView.swift
//  AlpacaTest_kiki
//
//  My Home reward payoff screen (HOME-01~06, HOME-C01~03). Owned by B.
//

import SwiftUI
import SwiftData

struct MyHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var modalState: CraftModalState?
    @State private var showAccountSettings = false
    @State private var showNotificationSettings = false

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }

        let fresh = UserProfile()
        modelContext.insert(fresh)
        return fresh
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        // 頁首：右上角保留「使用者頭貼」與「設定齒輪」兩個入口。
                        homeHeader

                        // HOME-C01：羊毛庫，顯示目前可使用羊毛總量。
                        woolBank

                        // HOME-C02：織品庫，顯示已成功製作並持有的織品。
                        textileLibrary

                        // HOME-C03：製作區，消耗羊毛並新增織品。
                        craftingArea
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 22)
                }
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("My Home")
                .navigationBarTitleDisplayMode(.inline)
            }

            if let modalState {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)

                modalContent(for: modalState)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: modalState?.id)
        .fullScreenCover(isPresented: $showAccountSettings) {
            AccountSettingsView(profile: profile)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(profile.name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    showAccountSettings = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 31))
                        .foregroundStyle(Theme.surfaceLavender)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.62), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("帳號設定")

                Button {
                    showNotificationSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.62), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("通知設定")
            }
        }
    }

    private var woolBank: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                SoftIconBadge(symbolName: "shippingbox.fill", tint: Theme.primary, size: 72, iconSize: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text("羊毛庫")
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Theme.primaryText)

                    Text("\(profile.woolBankG) g")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)

                    Text("目前可使用羊毛總量")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Divider().overlay(Theme.surfaceMint.opacity(0.65))

            Text("每天收割的羊毛都會慢慢存進這裡，累積成你努力過的柔軟證明。")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
        }
        .padding(24)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private var textileLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "織品庫", subtitle: "已成功製作並持有的獎勵物品")

            HStack(spacing: 10) {
                textileCountCard(item: .gloves, count: profile.gloveCount)
                textileCountCard(item: .scarf, count: profile.scarfCount)
                textileCountCard(item: .cape, count: profile.capeCount)
            }

            if profile.gloveCount + profile.scarfCount + profile.capeCount == 0 {
                Text("還沒有作品。完成一天、收成羊毛後，就可以開始製作。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
    }

    private var craftingArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "製作區", subtitle: "使用羊毛製作手套、圍巾與斗篷")

            VStack(spacing: 12) {
                ForEach(CraftItem.allCases) { item in
                    Button {
                        modalState = .confirm(item)
                    } label: {
                        craftRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func textileCountCard(item: CraftItem, count: Int) -> some View {
        VStack(spacing: 10) {
            SoftIconBadge(symbolName: item.symbolName, tint: item.tint, size: 46, iconSize: 22)

            Text(item.title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("× \(count)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(.white.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func craftRow(_ item: CraftItem) -> some View {
        let hasEnoughWool = profile.woolBankG >= item.costG

        return HStack(spacing: 14) {
            SoftIconBadge(symbolName: item.symbolName, tint: item.tint, size: 58, iconSize: 25, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("需要 \(item.costText) 羊毛")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text(hasEnoughWool ? "足夠" : "不足")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((hasEnoughWool ? Theme.highlight : Theme.surfaceLavender).opacity(0.32), in: Capsule())
        }
        .padding(16)
        .softFeedbackCard(surface: .white.opacity(0.58))
    }

    @ViewBuilder
    private func modalContent(for state: CraftModalState) -> some View {
        switch state {
        case .confirm(let item):
            ConfirmModal(
                title: "確認製作 \(item.title)？",
                message: "這次製作需要 \(item.costText) 羊毛。取消不會扣除羊毛，也不會新增織品。",
                primary: ModalAction(title: "確認製作") {
                    craft(item)
                },
                secondary: ModalAction(title: "取消") {
                    modalState = nil
                }
            )
        case .success(let item):
            ConfirmModal(
                title: "製作成功",
                message: "羊毛庫已扣除 \(item.costText)，\(item.title) 已新增到織品庫。",
                primary: ModalAction(title: "完成") {
                    modalState = nil
                }
            )
        case .insufficient(let item):
            ConfirmModal(
                title: "羊毛數量不足",
                message: "製作 \(item.title) 需要 \(item.costText)，目前有 \(profile.woolBankG) g。羊毛庫與織品庫不會變動。",
                primary: ModalAction(title: "關閉") {
                    modalState = nil
                }
            )
        }
    }

    private func craft(_ item: CraftItem) {
        guard profile.woolBankG >= item.costG else {
            modalState = .insufficient(item)
            return
        }

        // 同一個操作中扣羊毛並新增織品，避免兩邊資料不同步。
        profile.woolBankG -= item.costG

        switch item {
        case .gloves: profile.gloveCount += 1
        case .scarf: profile.scarfCount += 1
        case .cape: profile.capeCount += 1
        }

        try? modelContext.save()
        modalState = .success(item)
    }
}

private struct SoftIconBadge: View {
    let symbolName: String
    let tint: Color
    var size: CGFloat
    var iconSize: CGFloat
    var cornerRadius: CGFloat? = nil

    var body: some View {
        ZStack {
            if let cornerRadius {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.28))
            } else {
                Circle()
                    .fill(tint.opacity(0.28))
            }

            Image(systemName: symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: iconSize + 8, height: iconSize + 8)
        }
        .frame(width: size, height: size)
    }
}

struct AccountSettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draftName: String = ""
    @State private var isEditing = false
    @State private var avatarRefreshCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    SoftIconBadge(symbolName: "person.crop.circle.fill", tint: Theme.surfaceLavender, size: 132, iconSize: 82)

                    Button {
                        avatarRefreshCount += 1
                    } label: {
                        Label("更換頭貼", systemImage: "photo.fill")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.surfaceMint.opacity(0.55), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if avatarRefreshCount > 0 {
                        Text("頭貼選取器尚未接入，目前先保留入口。")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .padding(.top, 26)

                VStack(alignment: .leading, spacing: 12) {
                    Text("使用者名稱")
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Theme.primaryText)

                    if isEditing {
                        TextField("使用者名稱", text: $draftName)
                            .font(.system(.body, design: .rounded))
                            .padding(14)
                            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Text(profile.name)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text("帳號資訊")
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, 10)

                    Text("Demo account · Onboarding 建立")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
                .softFeedbackCard(surface: .white.opacity(0.58))

                Spacer()
            }
            .padding(.horizontal, 22)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("帳號設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") { dismiss() }
                        .foregroundStyle(Theme.primaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "儲存" : "編輯") {
                        if isEditing {
                            profile.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.name : draftName
                            try? modelContext.save()
                        } else {
                            draftName = profile.name
                        }
                        isEditing.toggle()
                    }
                    .foregroundStyle(Theme.primaryText)
                }
            }
        }
        .onAppear {
            draftName = profile.name
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("home.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("home.eodReminderMinutes") private var eodReminderMinutes = 21 * 60

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = eodReminderMinutes / 60
                components.minute = eodReminderMinutes % 60
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                eodReminderMinutes = (components.hour ?? 21) * 60 + (components.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("收割提醒", isOn: $notificationsEnabled)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .tint(Theme.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("每日提醒時間")
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Theme.primaryText)

                    DatePicker("結束今天／收割羊毛", selection: reminderDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .disabled(!notificationsEnabled)
                        .foregroundStyle(Theme.secondaryText)
                }

                Text("開啟後，今日任務中的「結束今天／收割羊毛」提醒會依這個時間出現。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(3)

                Spacer()
            }
            .padding(22)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.primaryText)
                }
            }
        }
    }
}

enum CraftItem: String, CaseIterable, Identifiable {
    case gloves
    case scarf
    case cape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gloves: return "手套"
        case .scarf: return "圍巾"
        case .cape: return "斗篷"
        }
    }

    var costG: Int {
        switch self {
        case .gloves: return 600
        case .scarf: return 1400
        case .cape: return 2800
        }
    }

    var costText: String {
        costG.formatted() + " g"
    }

    var symbolName: String {
        switch self {
        case .gloves: return "hand.raised.fill"
        case .scarf: return "wind"
        case .cape: return "person.fill"
        }
    }

    var tint: Color {
        switch self {
        case .gloves: return Theme.primary
        case .scarf: return Theme.surfaceLavender
        case .cape: return Theme.surfaceLeaf
        }
    }
}

enum CraftModalState: Identifiable {
    case confirm(CraftItem)
    case success(CraftItem)
    case insufficient(CraftItem)

    var id: String {
        switch self {
        case .confirm(let item): return "confirm-\(item.id)"
        case .success(let item): return "success-\(item.id)"
        case .insufficient(let item): return "insufficient-\(item.id)"
        }
    }
}

#Preview {
    MyHomeView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
