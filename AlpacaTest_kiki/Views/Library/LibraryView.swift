//
//  LibraryView.swift
//  AlpacaTest_kiki
//
//  任務庫。Owned by A. 兩種瀏覽方式用上方的 segmented 切換：
//    分類（LIB-C01 / LIB-C03，本檔）／時間（LIB-T01 / T02，LibraryCalendarView）
//  純瀏覽：分類方格 → 分類頁（依子分類分組）→ 點任務開共用編輯器。
//
//  ★ 未排日期區只放在「時間」模式（LibraryCalendarView）：startDate == nil 的
//    任務在今日頁（只查當天）看不到，在任務庫出現之前等於整個 App 裡都不存在。
//
//  刻意不做：拖拉、清單編輯模式、分類 CRUD。
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    /// 任務庫的兩種瀏覽方式：依分類（LIB-C）／依時間（LIB-T）
    private enum LibraryMode: String, CaseIterable {
        case category = "分類"
        case time     = "時間"
    }

    @Query(sort: \TodoTask.sortOrder) private var allTasks: [TodoTask]

    @State private var mode: LibraryMode = .category
    @State private var editingTask: TodoTask?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    /// 封存的不列入任務庫
    private var visibleTasks: [TodoTask] {
        allTasks.filter { $0.status != "archived" }
    }

    // MARK: - Grouping

    private var categoryBuckets: [CategoryBucket] {
        let grouped = Dictionary(grouping: visibleTasks) { $0.category }

        return grouped
            .map { category, tasks in
                CategoryBucket(
                    category: category,
                    count: tasks.count,
                    color: LibraryPalette.color(for: category, tasks: tasks)
                )
            }
            // 有分類的照名稱排，未分類永遠排最後
            .sorted { lhs, rhs in
                switch (lhs.category, rhs.category) {
                case (nil, nil):          return false
                case (nil, _):            return false
                case (_, nil):            return true
                case let (l?, r?):        return l.localizedCompare(r) == .orderedAscending
                }
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("瀏覽方式", selection: $mode) {
                        ForEach(LibraryMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .category:
                        categorySection
                    case .time:
                        LibraryCalendarView()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.alpacaCream.ignoresSafeArea())
            .navigationTitle("任務庫")
            .navigationDestination(for: CategoryBucket.self) { bucket in
                CategoryTasksView(category: bucket.category, accent: bucket.color)
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task)
        }
    }

    // MARK: - LIB-C01 分類方格

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類")
                .font(Theme.sectionTitleFont)
                .foregroundStyle(Color.alpacaBrown.opacity(0.75))

            if categoryBuckets.isEmpty {
                emptyHint("還沒有任何任務")
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(categoryBuckets) { bucket in
                        NavigationLink(value: bucket) {
                            CategoryCard(bucket: bucket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.alpacaCaption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

// MARK: - Models

/// 一個分類方格。category == nil 代表「未分類」。
struct CategoryBucket: Identifiable, Hashable {
    let category: String?
    let count: Int
    let color: Color

    var id: String { category ?? "\u{0}uncategorized" }
    var displayName: String { category ?? "未分類" }
}

/// 未排日期的兩種分組
enum UnscheduledGroup: Hashable {
    case urgent, later

    var title: String {
        switch self {
        case .urgent: return "緊急"
        case .later:  return "不緊急"
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.circle.fill"
        case .later:  return "tray.full.fill"
        }
    }
}

enum LibraryPalette {
    /// 分類顏色：優先沿用任務自己的 colorHex，否則用名稱穩定對應到主題色。
    /// 不用 hashValue —— 它每次啟動的種子不同，顏色會跳。
    static func color(for category: String?, tasks: [TodoTask]) -> Color {
        if let hex = tasks.compactMap({ $0.colorHex }).first,
           let parsed = Color(hex: hex) {
            return parsed
        }

        guard let category else { return Theme.tertiaryText }

        let palette: [Color] = [
            Theme.primary, Theme.surfaceMint, Theme.surfaceLavender, Theme.surfaceLeaf
        ]
        let stableIndex = category.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % palette.count
        return palette[stableIndex]
    }
}

// MARK: - Cards & rows

private struct CategoryCard: View {
    let bucket: CategoryBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Circle()
                .fill(bucket.color)
                .frame(width: 26, height: 26)

            Text(bucket.displayName)
                .font(.alpacaHeading)
                .foregroundStyle(Color.alpacaBrown)
                .lineLimit(1)

            Text("\(bucket.count) 個任務")
                .font(.alpacaCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(bucket.color.opacity(0.45), lineWidth: 1.5)
        )
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
