import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var isShowingImport = false

    var body: some View {
        NavigationStack {
            BookGridView(books: viewModel.books)
                .navigationTitle("Библиотека")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Добавить", systemImage: "plus") {
                            isShowingImport = true
                        }
                    }
                }
        }
    }
}
