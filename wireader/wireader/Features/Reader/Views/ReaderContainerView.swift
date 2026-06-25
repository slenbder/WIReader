import SwiftUI
import SwiftData

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel = ReaderViewModel()
    @State private var showSettings = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
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
                        },
                        onTap: {
                            toggleControls()
                        }
                    )
                } else if case .plainText(let text) = chapter.content {
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
                        },
                        onTap: {
                            toggleControls()
                        }
                    )
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
                    },
                    onTap: {
                        toggleControls()
                    }
                )
            }
        }
        .overlay {
            if controlsVisible {
                ReaderControlsView(
                    book: book,
                    viewModel: viewModel,
                    dismiss: {
                        hideControlsTask?.cancel()
                        dismiss()
                    },
                    showSettings: {
                        showSettings = true
                    },
                    onInteraction: {
                        showControlsAndScheduleHide()
                    }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet()
        }
        .task {
            await viewModel.load(book: book, fileStorage: FileStorageService(), context: modelContext)
            showControlsAndScheduleHide()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            viewModel.flushProgress(context: modelContext)
        }
    }

    private func toggleControls() {
        hideControlsTask?.cancel()
        if controlsVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        } else {
            showControlsAndScheduleHide()
        }
    }

    private func showControlsAndScheduleHide() {
        hideControlsTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        }
    }
}
