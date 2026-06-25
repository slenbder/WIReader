import SwiftUI

struct TableOfContentsView: View {
    let viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.chapters.indices, id: \.self) { index in
                Button {
                    viewModel.goToChapter(index)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(chapterTitle(at: index))
                            .fontWeight(index == viewModel.currentChapterIndex ? .semibold : .regular)
                            .foregroundStyle(index == viewModel.currentChapterIndex ? Color.accentColor : Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if index == viewModel.currentChapterIndex {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Оглавление")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func chapterTitle(at index: Int) -> String {
        let title = viewModel.chapters[index].title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let title, !title.isEmpty {
            return title
        }
        return "Глава \(index + 1)"
    }
}
