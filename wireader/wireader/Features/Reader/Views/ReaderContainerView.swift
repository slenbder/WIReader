import SwiftUI

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel = ReaderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Закрыть") { dismiss() }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.chapters.isEmpty,
                      let chapter = viewModel.currentChapter,
                      let tempDir = viewModel.tempDir {
                VStack(spacing: 0) {
                    EPUBReaderView(chapterURL: chapter.fileURL, allowedDir: tempDir)

                    // TODO: заменить на полные контролы в Phase 2.6
                    HStack {
                        Button("← Назад") { viewModel.goToPreviousChapter() }
                            .disabled(viewModel.currentChapterIndex == 0)
                        Spacer()
                        Text("\(viewModel.currentChapterIndex + 1) / \(viewModel.chapters.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Вперёд →") { viewModel.goToNextChapter() }
                            .disabled(viewModel.currentChapterIndex == viewModel.chapters.count - 1)
                    }
                    .padding()
                }
            }
        }
        .task {
            await viewModel.load(book: book, fileStorage: FileStorageService())
        }
    }
}
