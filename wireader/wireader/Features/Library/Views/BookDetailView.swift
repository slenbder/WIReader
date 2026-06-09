import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: Book
    @State private var viewModel: BookDetailViewModel
    @State private var showDeleteConfirmation = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(book: Book) {
        self.book = book
        _viewModel = State(initialValue: BookDetailViewModel(book: book))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                coverImage

                Text(book.title)
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                progressSection

                Button(viewModel.progress > 0 ? "Продолжить" : "Читать") {
                    viewModel.isReaderOpen = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Удалить книгу", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .padding(.top, 8)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Удалить книгу?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                Task {
                    try? await viewModel.deleteBook(
                        context: modelContext,
                        fileStorage: FileStorageService()
                    )
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $viewModel.isReaderOpen) {
            ReaderContainerView(book: viewModel.book)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 200, height: 280)
                .overlay(
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                )
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 6) {
            ProgressView(value: viewModel.progress)
                .padding(.horizontal, 32)
            Text(viewModel.progress > 0
                 ? "\(Int(viewModel.progress * 100))% прочитано"
                 : "Не начато")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
