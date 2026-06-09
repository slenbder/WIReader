import SwiftUI

struct TableOfContentsView: View {
    let viewModel: ReaderViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.chapters.indices, id: \.self) { index in
                Button(viewModel.chapters[index].title ?? "Глава \(index + 1)") {
                    viewModel.goToChapter(index)
                }
            }
            .navigationTitle("Оглавление")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
