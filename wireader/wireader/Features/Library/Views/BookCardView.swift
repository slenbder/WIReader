import SwiftUI

struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let data = book.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay(Image(systemName: "book.closed").font(.title))
            }
            Text(book.title)
                .font(.caption).bold()
                .lineLimit(2)
            if let author = book.author {
                Text(author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .cornerRadius(8)
    }
}
