import SwiftUI

struct NotesPanelView: View {
    let notes: [Note]

    var body: some View {
        NavigationStack {
            List(notes, id: \.id) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.selectedText).italic().font(.caption).foregroundStyle(.secondary)
                    Text(note.noteText)
                }
            }
            .navigationTitle("Заметки")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
