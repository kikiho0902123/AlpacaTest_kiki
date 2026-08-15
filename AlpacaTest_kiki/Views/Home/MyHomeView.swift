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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    homeHeader
                    woolBank
                    textileLibrary
                    craftingArea
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("My Home")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $modalState) { state in
            modalContent(for: state)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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
        HStack(spacing: 14) {
            Button {
                showAccountSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceLavender.opacity(0.42))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Theme.surfaceLavender)
                }
                .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("帳號設定")

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("今天也把成果帶回家")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Button {
                showNotificationSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知設定")
        }
    }

    private var woolBank: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceMint.opacity(0.55))
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.primary)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("羊毛庫")
                        .font(Theme.sectionTitleFont)
                        .foregroundStyle(Theme.primaryText)

                    Text("\(profile.woolBankG) g")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                }
            }

            Text("每日收割後的羊毛會存放在這裡；成功製作織品時會從這裡扣除。")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
        }
        .padding(24)
        .softFeedbackCard(surface: .white.opacity(0.72))
    }

    private var textileLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("織品庫")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 12) {
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
            Text("製作區")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Theme.primaryText)

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

    private func textileCountCard(item: CraftItem, count: Int) -> some View {
        VStack(spacing: 10) {
            Image(systemName: item.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(item.tint)

            Text(item.title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("× \(count)")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
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
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(item.tint.opacity(0.34))
                Image(systemName: item.symbolName)
                    .font(.system(size: 26))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 58, height: 58)

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

    private func modalContent(for state: CraftModalState) -> some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch state {
            case .confirm(let item):
                ConfirmModal(
                    title: "確認製作 \(item.title)？",
                    message: "這次製作需要 \(item.costText) 羊毛。確認後會檢查羊毛餘額。",
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
                    message: "\(item.title) 已放進織品庫。",
                    primary: ModalAction(title: "完成") {
                        modalState = nil
                    }
                )
            case .insufficient(let item):
                ConfirmModal(
                    title: "羊毛數量不足",
                    message: "製作 \(item.title) 需要 \(item.costText)，目前有 \(profile.woolBankG) g。",
                    primary: ModalAction(title: "關閉") {
                        modalState = nil
                    }
                )
            }
        }
    }

    private func craft(_ item: CraftItem) {
        guard profile.woolBankG >= item.costG else {
            modalState = .insufficient(item)
            return
        }

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

struct AccountSettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draftName: String = ""
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceLavender.opacity(0.42))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 82))
                        .foregroundStyle(Theme.surfaceLavender)
                }
                .frame(width: 132, height: 132)
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
                Toggle("通知權限", isOn: $notificationsEnabled)
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

                Text("修改後，今日任務中的「結束今天，收割羊毛！」通知島會依這個時間出現。")
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
        case .gloves: return "hands.sparkles.fill"
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
