import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = LibraryViewModel()
    @State private var isShowingImport = false
    @State private var showGrid = true

    #if DEBUG
    @State private var isShowingEPUBTest = false
    @State private var epubTestResult: String?
    @State private var isShowingTestAlert = false
    #endif

    private let allowedTypes: [UTType] = [
        UTType(filenameExtension: "epub") ?? .item,
        .pdf,
        .plainText,
        UTType(filenameExtension: "fb2") ?? .item,
    ]

    private var filteredBooks: [Book] {
        guard !viewModel.searchQuery.isEmpty else { return books }
        return books.filter {
            $0.title.localizedStandardContains(viewModel.searchQuery) ||
            $0.author?.localizedStandardContains(viewModel.searchQuery) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else if showGrid {
                    BookGridView(books: filteredBooks, onDelete: { id in await viewModel.deleteBook(id: id, books: books, context: modelContext) })
                } else {
                    bookList
                }
            }
            .navigationTitle("Библиотека")
            .searchable(text: $viewModel.searchQuery, prompt: "Поиск книг")
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Импорт...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить", systemImage: "plus") {
                        isShowingImport = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGrid.toggle()
                    } label: {
                        Image(systemName: showGrid ? "list.bullet" : "square.grid.2x2")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button("Test EPUB") { isShowingEPUBTest = true }
                        .font(.caption)
                }
                #endif
            }
            .fileImporter(
                isPresented: $isShowingImport,
                allowedContentTypes: allowedTypes
            ) { result in
                Task {
                    do {
                        let url = try result.get()
                        guard url.startAccessingSecurityScopedResource() else { return }
                        defer { url.stopAccessingSecurityScopedResource() }
                        await viewModel.importBook(from: url, context: modelContext)
                    } catch {
                        viewModel.importError = error
                        viewModel.isShowingError = true
                    }
                }
            }
            .alert("Ошибка импорта", isPresented: $viewModel.isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.importError?.localizedDescription ?? "Неизвестная ошибка")
            }
        }
        #if DEBUG
        .fileImporter(
            isPresented: $isShowingEPUBTest,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .item]
        ) { result in
            Task {
                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let parsed = try await EPUBParser().parse(url)
                    epubTestResult = """
                    Title: \(parsed.title)
                    Author: \(parsed.author ?? "—")
                    Chapters: \(parsed.chapters.count)
                    Cover: \(parsed.coverData != nil ? "yes" : "no")
                    First 3 chapters:
                    \(parsed.chapters.prefix(3).map { "  [\($0.index)] \($0.title)" }.joined(separator: "\n"))
                    """
                } catch {
                    epubTestResult = "Error: \(error.localizedDescription)"
                }
                isShowingTestAlert = true
            }
        }
        .alert("EPUB Parser Result", isPresented: $isShowingTestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(epubTestResult ?? "")
        }
        #endif
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Добавьте первую книгу")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var bookList: some View {
        List {
            ForEach(filteredBooks, id: \.id) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    HStack(spacing: 12) {
                        if let data = book.coverImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 44, height: 60)
                                .overlay(Image(systemName: "book.closed").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.body).bold()
                                .lineLimit(2)
                            if let author = book.author {
                                Text(author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .onDelete { indexSet in
                Task { @MainActor in
                    for idx in indexSet {
                        await viewModel.deleteBook(id: filteredBooks[idx].id, books: books, context: modelContext)
                    }
                }
            }
        }
        .listStyle(.plain)
    }


}
