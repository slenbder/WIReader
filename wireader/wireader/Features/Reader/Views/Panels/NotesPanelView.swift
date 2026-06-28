import SwiftUI

struct NotesPanelView: View {
    let notes: [Note]
    let onSelect: (Note) -> Void
    let onDelete: (Note) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteError = false

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "Нет заметок",
                        systemImage: "note.text",
                        description: Text("Выделите текст в книге и добавьте заметку.")
                    )
                } else {
                    List {
                        ForEach(notes, id: \.id) { note in
                            Button {
                                onSelect(note)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.selectedText)
                                        .font(.caption)
                                        .italic()
                                        .lineLimit(3)
                                        .foregroundStyle(.secondary)

                                    Text(note.noteText)
                                        .foregroundStyle(.primary)
                                        .lineLimit(4)

                                    Text(metadata(for: note))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            let deletionSucceeded = offsets
                                .map { notes[$0] }
                                .allSatisfy(onDelete)
                            showDeleteError = !deletionSucceeded
                        }
                    }
                }
            }
            .navigationTitle("Заметки")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Не удалось удалить заметку", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func metadata(for note: Note) -> String {
        let percent = Int((note.positionInChapter * 100).rounded())
        let date = note.dateCreated.formatted(date: .abbreviated, time: .shortened)
        return "Глава \(note.chapterIndex + 1) · \(percent)% · \(date)"
    }
}
