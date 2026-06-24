import SwiftUI
import SwiftData

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel = ReaderViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                      let chapter = viewModel.currentChapter {
                if case .html(let fileURL) = chapter.content, let tempDir = viewModel.tempDir {
                    VStack(spacing: 0) {
                        EPUBReaderView(
                            chapterURL: fileURL,
                            allowedDir: tempDir,
                            onProgressUpdate: { position in
                                viewModel.onScrollProgress(position, context: modelContext)
                            },
                            onWebViewReady: { wv in
                                viewModel.setWebView(wv)
                            },
                            onPageLoaded: {
                                viewModel.applyPendingScroll()
                            }
                        )
                        chapterNavBar
                    }
                } else if case .plainText(let text) = chapter.content {
                    VStack(spacing: 0) {
                        TextReaderView(
                            text: text,
                            chapterTitle: chapter.title,
                            scrollPosition: viewModel.positionInChapter,
                            restoreToken: viewModel.restoreToken,
                            onProgressUpdate: { position in
                                viewModel.onScrollProgress(position, context: modelContext)
                            },
                            onFlushProgress: {
                                viewModel.flushProgress(context: modelContext)
                            }
                        )
                        chapterNavBar
                    }
                }
            } else if let pdfURL = viewModel.pdfURL {
                PDFReaderView(
                    fileURL: pdfURL,
                    positionInChapter: viewModel.positionInChapter,
                    restoreToken: viewModel.restoreToken,
                    onProgressUpdate: { position in
                        viewModel.onScrollProgress(position, context: modelContext)
                    },
                    onFlushProgress: {
                        viewModel.flushProgress(context: modelContext)
                    }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading)
            .padding(.top, 8)
        }
        .task {
            await viewModel.load(book: book, fileStorage: FileStorageService(), context: modelContext)
        }
        .onDisappear {
            viewModel.flushProgress(context: modelContext)
        }
    }

    // TODO: заменить на полные контролы в Phase 2.6
    private var chapterNavBar: some View {
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
