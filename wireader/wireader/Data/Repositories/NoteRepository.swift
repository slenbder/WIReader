import Foundation
import SwiftData

@MainActor
final class NoteRepository {

    func fetch(bookId: UUID, context: ModelContext) -> [Note] {
        let id = bookId
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.bookId == id },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func add(
        book: Book,
        chapterIndex: Int,
        positionInChapter: Double,
        selectedText: String,
        noteText: String,
        context: ModelContext
    ) throws -> Note {
        let note = Note()
        note.bookId = book.id
        note.chapterIndex = chapterIndex
        note.positionInChapter = min(max(positionInChapter, 0.0), 1.0)
        note.selectedText = selectedText
        note.noteText = noteText
        note.dateCreated = Date()

        context.insert(note)
        book.notes.append(note)
        try context.save()
        return note
    }

    func delete(_ note: Note, from book: Book, context: ModelContext) throws {
        book.notes.removeAll { $0.id == note.id }
        context.delete(note)
        try context.save()
    }
}
