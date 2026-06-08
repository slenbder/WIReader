import SwiftUI

struct ChapterSummarySheet: View {
    let book: Book
    let chapterIndex: Int
    @State private var viewModel = AIViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.streamedResponse.isEmpty ? "Загружаю саммари..." : viewModel.streamedResponse)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Саммари главы")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.summarizeChapter(book: book, chapterIndex: chapterIndex)
        }
    }
}
