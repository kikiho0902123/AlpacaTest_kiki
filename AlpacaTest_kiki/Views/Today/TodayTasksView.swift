//
//  TodayTasksView.swift
//  AlpacaTest_kiki
//
//  Today main screen (TOD-01). Owned by A.
//  Phase 1: minimal migration onto TodoTask.
//  TODO(Phase 2): rename to TodayView, extract AlpacaStatusView (image only, no numbers — STATE-09),
//  three groups (To-do / Split / Done), "End the day" island (EOD-01).
//

import SwiftUI
import SwiftData

struct TodayTasksView: View {
    @Query(sort: \TodoTask.createdAt) private var allTasks: [TodoTask]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false

    // 未完成在前，已完成在後
    private var sortedTasks: [TodoTask] {
        allTasks.sorted { lhs, rhs in
            let lDone = lhs.status == "done"
            let rDone = rhs.status == "done"
            if lDone != rDone { return !lDone }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.alpacaCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // AlpacaStatusView placeholder — image only, NO numbers, NO caption (STATE-09).
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
        .modelContainer(for: TodoTask.self, inMemory: true)
}
