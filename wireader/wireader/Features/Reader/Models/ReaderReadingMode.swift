enum ReaderReadingMode: String, CaseIterable, Identifiable {
    case scroll
    case paging

    var id: Self { self }

    init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .scroll
    }

    var displayName: String {
        switch self {
        case .scroll:
            "Прокрутка"
        case .paging:
            "Страницы"
        }
    }
}
