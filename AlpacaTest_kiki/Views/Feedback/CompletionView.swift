//
//  CompletionView.swift
//  AlpacaTest_kiki
//
//  Task completion flow (TOD-05/06). Owned by B.
//

import SwiftUI
import SwiftData

struct CompletionView: View {
    @Bindable var task: TodoTask
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var phase: CompletionPhase = .confirm
    @State private var note = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch phase {
            case .confirm:
                ConfirmModal(
                    title: "完成這個任務了嗎？",
                    message: "確認後會把任務移到已完成，並記錄今天的成果。",
                    primary: ModalAction(title: "完成了") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .note
                        }
                    },
                    secondary: ModalAction(title: "還沒完成") {
                        onFinish()
                    }
                )
            case .note:
                completionNoteView
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var completionNoteView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("留一句完成回饋")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("可以寫下今天做到哪一步、心情，或任何想留給未來自己的線索。")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
            }

            TextEditor(text: $note)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 150)
                .background(
                    RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                        .fill(.white.opacity(0.72))
                )
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("例如：今天終於把第一版整理出來了。")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            VStack(spacing: 10) {
                Button {
                    finish(writesNote: true)
                } label: {
                    Text("Done")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button {
                    finish(writesNote: false)
                } label: {
                    Text("Skip")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
        .softFeedbackCard(surface: .white.opacity(0.58))
        .padding(24)
    }

    private func finish(writesNote: Bool) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        task.status = "done"
        task.progress = 1.0

        if writesNote && !trimmedNote.isEmpty {
            modelContext.insert(TaskLog(taskID: task.id, type: "completion", content: trimmedNote))
        }

        RewardEngine.grant(.complete(task.complexity), context: modelContext)

        if writesNote && !trimmedNote.isEmpty {
            RewardEngine.grant(.completionNoteBonus, context: modelContext)
        }

        try? modelContext.save()
        onFinish()
    }
}

private enum CompletionPhase {
    case confirm
    case note
}

#Preview {
    let task = TodoTask(name: "完成簡報")
    return CompletionView(task: task) {}
        .modelContainer(for: [TodoTask.self, TaskLog.self, DailyStat.self], inMemory: true)
}
