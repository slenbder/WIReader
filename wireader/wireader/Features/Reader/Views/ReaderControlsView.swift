import SwiftUI

struct ReaderControlsView: View {
    let book: Book
    let viewModel: ReaderViewModel
    let dismiss: () -> Void
    let showSettings: () -> Void
    let showTableOfContents: () -> Void
    let addBookmark: () -> Void
    let showBookmarks: () -> Void
    let onInteraction: () -> Void

    var body: some View {
        VStack {
            topBar

            Spacer()

            bottomBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            controlButton(systemName: "xmark", action: dismiss)

            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            controlButton(systemName: "list.bullet", action: showTableOfContents)
                .disabled(viewModel.chapters.isEmpty)
            controlButton(systemName: "bookmark", action: addBookmark)
            controlButton(systemName: "bookmark.fill", action: showBookmarks)
            controlButton(systemName: "note.text", action: {})
            controlButton(systemName: "textformat.size", action: showSettings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ProgressView(value: viewModel.overallProgress)
                .tint(.primary)

            HStack(spacing: 12) {
                Button {
                    onInteraction()
                    viewModel.goToPreviousChapter()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .disabled(viewModel.currentChapterIndex == 0 || viewModel.chapters.isEmpty)

                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                if !viewModel.chapters.isEmpty {
                    Text("\(viewModel.currentChapterIndex + 1) / \(viewModel.chapters.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button {
                    onInteraction()
                    viewModel.goToNextChapter()
                } label: {
                    Label("Вперёд", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
                .disabled(
                    viewModel.chapters.isEmpty ||
                    viewModel.currentChapterIndex >= viewModel.chapters.count - 1
                )
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var progressText: String {
        "\(Int((viewModel.overallProgress * 100).rounded()))%"
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            onInteraction()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
