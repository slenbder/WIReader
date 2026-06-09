import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = LibraryViewModel()
    @State private var isShowingImport = false

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

    var body: some View {
        NavigationStack {
            BookGridView(books: books)
                .navigationTitle("Библиотека")
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
}
