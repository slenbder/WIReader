import SwiftUI
import SwiftData

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel = ReaderViewModel()
    @State private var showSettings = false
    @State private var showTableOfContents = false
    @State private var showBookmarks = false
    @State private var showNotes = false
    @State private var showEPUBNoteAction = false
    @State private var pendingSelection: ReaderTextSelection?
    @State private var editingSelection: ReaderTextSelection?
    @State private var draftNoteText = ""
    @State private var showNoteSaveError = false
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "light"
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("readerMargins") private var readerMargins: Double = 16
    @AppStorage("readerFontName") private var readerFontName: String = "system"
    @AppStorage("readingMode") private var readingModeRawValue: String = ReaderReadingMode.scroll.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let theme = ReaderTheme.theme(for: selectedThemeId)
        let readingMode = ReaderReadingMode(storedValue: readingModeRawValue)
        let supportsPagingMode = book.format == "epub"
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
                        chapterIndex: viewModel.currentChapterIndex,
                        scrollPosition: viewModel.positionInChapter,
                        restoreToken: viewModel.restoreToken,
                        readingMode: supportsPagingMode ? readingMode : .scroll,
                        theme: theme,
                        onProgressUpdate: { position in
                            viewModel.onScrollProgress(position, context: modelContext)
                        },
                        onWebViewReady: { wv in
                            viewModel.setWebView(wv)
                        },
                        onPageLoaded: {
                            viewModel.applyPendingEPUBPosition()
                        },
                        onPageSettled: { position in
                            viewModel.onEPUBPageSettled(position, context: modelContext)
                        },
                        onTap: {
                            toggleControls()
                        },
                        onSelectionChange: { selection in
                            guard selection?.chapterIndex == viewModel.currentChapterIndex else {
                                pendingSelection = nil
                                showEPUBNoteAction = false
                                return
                            }
                            pendingSelection = selection
                            showEPUBNoteAction = selection?.isValid == true
                        }
                    )
                } else if case .plainText(let text) = chapter.content {
                    TextReaderView(
                        text: text,
                        chapterTitle: chapter.title,
                        chapterIndex: viewModel.currentChapterIndex,
                        scrollPosition: viewModel.positionInChapter,
                        restoreToken: viewModel.restoreToken,
                        readingMode: .scroll,
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
                        },
                        onCreateNoteFromSelection: { selection in
                            beginNote(for: selection)
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
                    showTableOfContents: {
                        showTableOfContents = true
                    },
                    addBookmark: {
                        viewModel.addBookmark(context: modelContext)
                    },
                    showBookmarks: {
                        viewModel.loadBookmarks(context: modelContext)
                        showBookmarks = true
                    },
                    showNotes: {
                        viewModel.loadNotes(context: modelContext)
                        showNotes = true
                    },
                    onInteraction: {
                        showControlsAndScheduleHide()
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if showEPUBNoteAction, let selection = pendingSelection, selection.isValid, editingSelection == nil {
                Button {
                    beginNote(for: selection)
                } label: {
                    Label("Добавить заметку", systemImage: "note.text")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, controlsVisible ? 88 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(supportsPagingMode: supportsPagingMode)
        }
        .sheet(isPresented: $showTableOfContents) {
            TableOfContentsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksPanelView(
                bookmarks: viewModel.bookmarks,
                onSelect: { bookmark in
                    viewModel.goToBookmark(bookmark)
                },
                onDelete: { bookmark in
                    viewModel.deleteBookmark(bookmark, context: modelContext)
                }
            )
        }
        .sheet(isPresented: $showNotes) {
            NotesPanelView(
                notes: viewModel.notes,
                onSelect: { note in
                    viewModel.goToNote(note)
                },
                onDelete: { note in
                    viewModel.deleteNote(note, context: modelContext)
                }
            )
        }
        .sheet(item: $editingSelection, onDismiss: clearPendingNote) { selection in
            NoteEditorView(
                selectedText: selection.selectedText,
                noteText: $draftNoteText,
                showSaveError: $showNoteSaveError,
                onCancel: {
                    editingSelection = nil
                },
                onSave: {
                    saveNote(for: selection)
                }
            )
        }
        .task {
            await viewModel.load(book: book, fileStorage: FileStorageService(), context: modelContext)
            showControlsAndScheduleHide()
        }
        .onChange(of: viewModel.currentChapterIndex) { _, newChapterIndex in
            guard editingSelection == nil,
                  pendingSelection?.chapterIndex != newChapterIndex
            else { return }
            pendingSelection = nil
            showEPUBNoteAction = false
        }
        .onChange(of: readingModeRawValue) { _, _ in
            guard book.format == "epub" else { return }
            viewModel.prepareEPUBModeSwitch()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            viewModel.flushProgress(context: modelContext)
        }
    }

    private func beginNote(for selection: ReaderTextSelection) {
        guard selection.isValid else { return }
        pendingSelection = selection
        draftNoteText = ""
        showNoteSaveError = false
        showEPUBNoteAction = false
        editingSelection = selection
    }

    private func saveNote(for selection: ReaderTextSelection) {
        guard selection.isValid else { return }
        let didSave = viewModel.addNote(
            selectedText: selection.selectedText,
            noteText: draftNoteText,
            chapterIndex: selection.chapterIndex,
            positionInChapter: selection.positionInChapter,
            context: modelContext
        )
        if didSave {
            editingSelection = nil
        } else {
            showNoteSaveError = true
        }
    }

    private func clearPendingNote() {
        pendingSelection = nil
        editingSelection = nil
        draftNoteText = ""
        showNoteSaveError = false
        showEPUBNoteAction = false
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

private struct NoteEditorView: View {
    let selectedText: String
    @Binding var noteText: String
    @Binding var showSaveError: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Выделенный текст") {
                    Text(selectedText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("Заметка") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 140)
                }
            }
            .navigationTitle("Новая заметка")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Не удалось сохранить заметку", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: onSave)
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
