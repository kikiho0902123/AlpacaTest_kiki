//
//  TaskCardView.swift
//  AlpacaTest_kiki
//
//  Created by kikiho on 2026/8/13.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    @Bindable var task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 名稱 + 閃電 + 電量圖示
            HStack(alignment: .top) {
                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(Color.alpacaBrown)
                    .strikethrough(task.isCompleted)

                Spacer()

                HStack(spacing: 8) {
                    if task.isMustDoToday {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.alpacaOrange)
                    }
                    Image(systemName: task.difficulty.batteryIcon)
                        .foregroundStyle(Color.alpacaBrown.opacity(0.7))
                }
            }

            if task.isStuck {
                Label("卡住了", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.alpacaStuck)
            }

            // 可拉的進度條：手動回報完成度
            VStack(alignment: .leading, spacing: 4) {
                Slider(value: $task.progress, in: 0...1, step: 0.01)
                    .tint(task.isCompleted ? Color.alpacaGreen : Color.alpacaTerracotta)
                    .disabled(task.isCompleted)

                Text("完成度 \(Int(task.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 操作按鈕列：開始 / 完成 / 卡住了
            HStack(spacing: 10) {
                Button {
                    task.isStarted = true
                } label: {
                    Label("開始", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(Color.alpacaBrown)
                .disabled(task.isStarted || task.isCompleted)

                Button {
                    task.isCompleted = true
                    task.progress = 1.0
                    task.completedAt = Date()
                } label: {
                    Label("完成", systemImage: "checkmark")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.alpacaGreen)
                .disabled(task.isCompleted)

                Spacer()

                Button {
                    task.isStuck.toggle()
                } label: {
                    Label(task.isStuck ? "已標記" : "卡住了", systemImage: "hand.raised.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(task.isStuck ? Color.alpacaStuck : .gray)
                .disabled(task.isCompleted)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(task.isStuck ? Color.alpacaStuck.opacity(0.12) : Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(task.isStuck ? Color.alpacaStuck.opacity(0.5) : Color.alpacaBeige, lineWidth: 1.5)
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .animation(.easeInOut, value: task.isCompleted)
        .animation(.easeInOut, value: task.isStuck)
    }
}

#Preview {
    TaskCardView(task: TaskItem(name: "整理書桌", isMustDoToday: true, difficulty: .medium))
        .padding()
        .background(Color.alpacaCream)
}
