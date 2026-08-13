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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TaskItem.self)
    }
}
