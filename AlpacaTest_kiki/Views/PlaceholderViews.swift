//
//  PlaceholderView.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI

// 任務庫 - 之後再開發
struct TaskLibraryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.alpacaOrange.opacity(0.6))
                Text("任務庫\n（開發中）")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.alpacaCream.ignoresSafeArea())
            .navigationTitle("任務庫")
        }
    }
}


// 個人化設定 - 之後再開發
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.alpacaOrange.opacity(0.6))
                Text("個人化設定\n（開發中）")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.alpacaCream.ignoresSafeArea())
            .navigationTitle("個人化設定")
        }
    }
}

#Preview("任務庫") { TaskLibraryView() }
#Preview("個人化設定") { SettingsView() }
