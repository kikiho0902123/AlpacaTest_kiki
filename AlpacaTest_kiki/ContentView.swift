//
//  ContentView.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TodayTasksView()
                .tabItem {
                    Label("今日任務", systemImage: "sun.max.fill")
                }

            TaskLibraryView()
                .tabItem {
                    Label("任務庫", systemImage: "books.vertical.fill")
                }

            FeedbackView()
                .tabItem {
                    Label("回饋", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("個人化設定", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(.alpacaTerracotta)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self], inMemory: true)
}
