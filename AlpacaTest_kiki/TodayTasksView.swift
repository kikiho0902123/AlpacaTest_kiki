//
//  TodayTasksView.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI
import SwiftData

struct TodayTasksView: View {
    @Query(sort: \TaskItem.createdAt) private var allTasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false

    // 未完成在前，已完成在後
    private var sortedTasks: [TaskItem] {
        allTasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.alpacaCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // TODO: 換成你自己的羊駝吉祥物圖片（Assets 裡加一張圖，改用 Image("你的圖片名稱")）
                        Image(systemName: "pawprint.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundStyle(Color.alpacaOrange)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity)

                        if sortedTasks.isEmpty {
                            Text("今天還沒有任務，點右下角加號新增一個吧！")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                                .padding(.horizontal, 32)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(sortedTasks) { task in
                                TaskCardView(task: task)
                                    .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 80)
                    }
                }

                // 右下角新增任務按鈕
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.alpacaTerracotta))
                        .shadow(radius: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("今日任務")
        }
        .sheet(isPresented: $showAddSheet) {
            AddTaskView()
        }
    }
}

#Preview {
    TodayTasksView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
