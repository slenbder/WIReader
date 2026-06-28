import SwiftUI

struct ReaderSettingsSheet: View {
    let supportsPagingMode: Bool

    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("readerMargins") private var readerMargins: Double = 16
    @AppStorage("readerFontName") private var readerFontName: String = "system"
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "light"
    @AppStorage("readingMode") private var readingModeRawValue: String = ReaderReadingMode.scroll.rawValue

    var body: some View {
        NavigationStack {
            Form {
                if supportsPagingMode {
                    Section("Режим чтения") {
                        Picker("Режим", selection: readingModeBinding) {
                            ForEach(ReaderReadingMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Тема") {
                    ForEach(ReaderTheme.all) { theme in
                        Button {
                            selectedThemeId = theme.id
                        } label: {
                            HStack(spacing: 12) {
                                ThemePreview(theme: theme)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(theme.name)
                                        if theme.isPremium {
                                            Text("Premium")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Text("Aa Быстрый просмотр")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryTextColor)
                                }
                                Spacer()
                                if selectedThemeId == theme.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Шрифт") {
                    Picker("Гарнитура", selection: $readerFontName) {
                        Text("System").tag("system")
                        Text("Serif").tag("serif")
                        Text("Rounded").tag("rounded")
                        Text("Mono").tag("monospaced")
                    }

                    VStack(alignment: .leading) {
                        Text("Размер: \(Int(fontSize))")
                        Slider(value: $fontSize, in: 12...32, step: 1)
                    }
                }

                Section("Межстрочный интервал") {
                        Text("Интервал: \(String(format: "%.1f", lineSpacing))")
                    Slider(value: $lineSpacing, in: 1.0...2.0, step: 0.1)
                }

                Section("Поля") {
                    Text("Отступ: \(Int(readerMargins))")
                    Slider(value: $readerMargins, in: 8...40, step: 2)
                }
            }
            .navigationTitle("Настройки чтения")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var readingModeBinding: Binding<ReaderReadingMode> {
        Binding(
            get: { ReaderReadingMode(storedValue: readingModeRawValue) },
            set: { readingModeRawValue = $0.rawValue }
        )
    }
}

private struct ThemePreview: View {
    let theme: ReaderTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.backgroundColor)
            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textColor)
                    .frame(width: 32, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.secondaryTextColor)
                    .frame(width: 24, height: 3)
            }
        }
        .frame(width: 52, height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.secondary.opacity(0.25), lineWidth: 1)
        }
    }
}
