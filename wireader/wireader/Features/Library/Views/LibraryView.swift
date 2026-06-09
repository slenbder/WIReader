import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var isShowingImport = false

    #if DEBUG
    @State private var isShowingEPUBTest = false
    @State private var epubTestResult: String?
    @State private var isShowingTestAlert = false
    #endif

    var body: some View {
        NavigationStack {
            BookGridView(books: viewModel.books)
                .navigationTitle("Библиотека")
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
}
