//
//  AlpacaTaskApp.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI
import SwiftData

@main
struct AlpacaTaskApp: App {
    /// Built explicitly (rather than via `.modelContainer(for:)`) so C's demo seed is
    /// loaded BEFORE any @Query runs. `loadIfNeeded` no-ops once a UserProfile exists,
    /// so this is safe on every launch — wipe the simulator to re-seed.
    private let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: TodoTask.self, TaskLog.self, ChatMessage.self, DailyStat.self, UserProfile.self
            )
            SeedData.loadIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("ModelContainer 建立失敗：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
