import Foundation

struct BookChapter {
    let index: Int
    let title: String?
    let content: ChapterContent
}

enum ChapterContent {
    case html(fileURL: URL)
    case plainText(String)
}
