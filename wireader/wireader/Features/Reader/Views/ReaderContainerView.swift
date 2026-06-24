import SwiftUI
import SwiftData

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel = ReaderViewModel()
    @State private var showSettings = false
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "light"
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("readerMargins") private var readerMargins: Double = 16
    @AppStorage("readerFontName") private var readerFontName: String = "system"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let theme = ReaderTheme.theme(for: selectedThemeId)
        let textStyle = TextReaderStyle(
            bodyFontSize: CGFloat(fontSize),
            titleFontSize: CGFloat(fontSize + 5),
            lineSpacing: CGFloat(lineSpacing),
            paragraphSpacing: CGFloat(fontSize * 0.7),
            margins: CGFloat(readerMargins),
            fontName: readerFontName
        )

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
                            theme: theme,
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
                            style: textStyle,
                            theme: theme,
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
        .overlay(alignment: .topTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "textformat.size")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet()
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
