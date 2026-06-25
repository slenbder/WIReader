import SwiftUI
import UIKit

struct TextReaderStyle: Equatable {
    var bodyFontSize: CGFloat = 18
    var titleFontSize: CGFloat = 23
    var lineSpacing: CGFloat = 1.4
    var paragraphSpacing: CGFloat = 12.6
    var margins: CGFloat = 16
    var fontName: String = "system"
}

// MARK: - PositionRestoringTextView

// layoutSubviews is the only UIKit-guaranteed point where bounds are valid.
// pendingPosition is set by updateUIView and consumed (set to nil) exactly once,
// on the first layoutSubviews call where bounds.height > 0.
final class PositionRestoringTextView: UITextView {
    var pendingPosition: Double?
    var onRestoreReady: ((Double) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0, let position = pendingPosition else { return }
        pendingPosition = nil
        onRestoreReady?(position)
    }
}

// MARK: - TextReaderView

struct TextReaderView: UIViewRepresentable {
    let text: String
    let chapterTitle: String?
    let scrollPosition: Double
    let restoreToken: Int
    var style: TextReaderStyle = TextReaderStyle()
    let theme: ReaderTheme
    var onProgressUpdate: (Double) -> Bool
    var onFlushProgress: () -> Void
    var onTap: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgressUpdate: onProgressUpdate, onFlushProgress: onFlushProgress)
    }

    func makeUIView(context: Context) -> PositionRestoringTextView {
        let textView = PositionRestoringTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textContainerInset = contentInsets
        textView.backgroundColor = theme.uiBackgroundColor
        textView.delegate = context.coordinator
        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = context.coordinator
        textView.addGestureRecognizer(tapRecognizer)
        textView.onRestoreReady = { [weak textView, weak coordinator = context.coordinator] position in
            guard let textView, let coordinator else { return }
            coordinator.applyPosition(textView, position: position)
            UIView.animate(withDuration: 0.15) { textView.alpha = 1 }
        }
        return textView
    }

    func updateUIView(_ textView: PositionRestoringTextView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onFlushProgress = onFlushProgress
        context.coordinator.onTap = onTap

        let textChanged = context.coordinator.lastText != text
        let tokenChanged = context.coordinator.lastRestoreToken != restoreToken
        let themeChanged = context.coordinator.lastThemeId != theme.id
        let styleChanged = context.coordinator.lastStyle != style

        if textChanged {
            // isRestoringPosition prevents UITextView's internal offset reset
            // from firing scrollViewDidScroll and overwriting saved progress with 0
            context.coordinator.isRestoringPosition = true
            context.coordinator.lastText = text
            textView.textContainerInset = contentInsets
            textView.attributedText = buildAttributedString()
            if !tokenChanged {
                // Chapter navigation: UITextView does NOT reset contentOffset on
                // attributedText change — the old offset survives. Kill live inertia
                // first (setContentOffset to current offset stops deceleration), then
                // scroll to top. scrollPosition is intentionally ignored here: inertial
                // scroll events from the old chapter can arrive after goTo* set
                // positionInChapter=0, making scrollPosition a stale race value.
                textView.setContentOffset(textView.contentOffset, animated: false)
                textView.setContentOffset(CGPoint(x: 0, y: -textView.adjustedContentInset.top), animated: false)
            }
            context.coordinator.isRestoringPosition = false
            if !tokenChanged {
                // Sync VM: flush on immediate close after navigation must write 0.0,
                // not the stale inertial fraction that lost the race above.
                _ = onProgressUpdate(0.0)
            }
        }

        if (themeChanged || styleChanged) && !textChanged {
            context.coordinator.applyStyleOnlyUpdate(
                textView,
                attributedText: buildAttributedString(),
                theme: theme,
                insets: contentInsets
            )
        } else {
            textView.backgroundColor = theme.uiBackgroundColor
        }
        context.coordinator.lastThemeId = theme.id
        context.coordinator.lastStyle = style

        if textChanged || tokenChanged {
            context.coordinator.lastRestoreToken = restoreToken
            if tokenChanged {
                // Book open/restore: scrollPosition is reliable (load() sets it
                // before mutating currentChapterIndex, so no race possible).
                if scrollPosition > 0 {
                    textView.alpha = 0
                    textView.pendingPosition = scrollPosition
                } else {
                    textView.alpha = 1
                    textView.pendingPosition = nil
                }
            } else {
                // Chapter navigation: always show from top, scrollPosition ignored.
                textView.alpha = 1
                textView.pendingPosition = nil
            }
        }
    }

    // MARK: - Private

    private func buildAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()

        if let title = chapterTitle, !title.isEmpty {
            let titleStyle = NSMutableParagraphStyle()
            titleStyle.lineHeightMultiple = style.lineSpacing
            titleStyle.paragraphSpacing = style.paragraphSpacing * 2
            result.append(NSAttributedString(string: title + "\n\n", attributes: [
                .font: titleFont(),
                .foregroundColor: theme.uiTextColor,
                .paragraphStyle: titleStyle
            ]))
        }

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineHeightMultiple = style.lineSpacing
        bodyStyle.paragraphSpacing = style.paragraphSpacing
        result.append(NSAttributedString(string: text, attributes: [
            .font: bodyFont(),
            .foregroundColor: theme.uiTextColor,
            .paragraphStyle: bodyStyle
        ]))

        return result
    }

    private var contentInsets: UIEdgeInsets {
        UIEdgeInsets(top: style.margins, left: style.margins, bottom: style.margins, right: style.margins)
    }

    private func bodyFont() -> UIFont {
        font(size: style.bodyFontSize, bold: false)
    }

    private func titleFont() -> UIFont {
        font(size: style.titleFontSize, bold: true)
    }

    private func font(size: CGFloat, bold: Bool) -> UIFont {
        switch style.fontName {
        case "serif":
            return UIFont(name: bold ? "Georgia-Bold" : "Georgia", size: size)
                ?? (bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size))
        case "rounded":
            let weight: UIFont.Weight = bold ? .bold : .regular
            let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded)
            return descriptor.map { UIFont(descriptor: $0, size: size) }
                ?? (bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size))
        case "monospaced":
            return bold
                ? UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
                : UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        default:
            return bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        }
    }
}

// MARK: - Coordinator

extension TextReaderView {
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var onProgressUpdate: (Double) -> Bool
        var onFlushProgress: () -> Void
        var onTap: () -> Void = {}
        var lastText: String?
        var lastRestoreToken: Int = -1
        var lastThemeId: String?
        var lastStyle: TextReaderStyle?
        var isRestoringPosition = false

        init(onProgressUpdate: @escaping (Double) -> Bool, onFlushProgress: @escaping () -> Void) {
            self.onProgressUpdate = onProgressUpdate
            self.onFlushProgress = onFlushProgress
        }

        func applyPosition(_ textView: UITextView, position: Double) {
            // ensureLayout at boundsH=0 returns a partial usageBounds (the original bug:
            // 1622 instead of 2647). Hard guard here so we never compute with bad geometry.
            guard textView.bounds.height > 0 else { return }
            // ensureLayout forces TextKit 2 to compute the full document before reading
            // usageBoundsForTextContainer. contentSize.height is a lazy UITextView estimate
            // that diverges from the actual layout height; usageBoundsForTextContainer + insets
            // is always the ground truth after ensureLayout.
            if let tlm = textView.textLayoutManager, let doc = tlm.textContentManager?.documentRange {
                tlm.ensureLayout(for: doc)
            }
            let insets = textView.textContainerInset
            let totalH: CGFloat
            if let tlm = textView.textLayoutManager {
                totalH = tlm.usageBoundsForTextContainer.height + insets.top + insets.bottom
            } else {
                totalH = textView.contentSize.height
            }
            let maxY = max(totalH - textView.bounds.height, 0)
            isRestoringPosition = true
            textView.setContentOffset(CGPoint(x: 0, y: maxY * position), animated: false)
            isRestoringPosition = false
        }

        func applyStyleOnlyUpdate(
            _ textView: UITextView,
            attributedText: NSAttributedString,
            theme: ReaderTheme,
            insets: UIEdgeInsets
        ) {
            let position = currentPosition(in: textView)
            isRestoringPosition = true
            textView.backgroundColor = theme.uiBackgroundColor
            textView.textContainerInset = insets
            textView.attributedText = attributedText
            applyPosition(textView, position: position)
            isRestoringPosition = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Same formula as applyPosition: ensureLayout + usageBounds + insets.
            // ensureLayout is a no-op after the first call (layout already computed),
            // so the per-frame cost is negligible after the initial layout pass.
            let totalH: CGFloat
            if let textView = scrollView as? UITextView,
               let tlm = textView.textLayoutManager,
               let doc = tlm.textContentManager?.documentRange {
                tlm.ensureLayout(for: doc)
                let insets = textView.textContainerInset
                totalH = tlm.usageBoundsForTextContainer.height + insets.top + insets.bottom
            } else {
                totalH = scrollView.contentSize.height
            }
            let maxH = max(totalH - scrollView.bounds.height, 1)
            let position = min(max(scrollView.contentOffset.y / maxH, 0), 1)
            guard !isRestoringPosition else { return }
            _ = onProgressUpdate(position)
        }

        private func currentPosition(in textView: UITextView) -> Double {
            let totalH: CGFloat
            if let tlm = textView.textLayoutManager,
               let doc = tlm.textContentManager?.documentRange {
                tlm.ensureLayout(for: doc)
                let insets = textView.textContainerInset
                totalH = tlm.usageBoundsForTextContainer.height + insets.top + insets.bottom
            } else {
                totalH = textView.contentSize.height
            }
            let maxH = max(totalH - textView.bounds.height, 1)
            return min(max(textView.contentOffset.y / maxH, 0), 1)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            onFlushProgress()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { onFlushProgress() }
        }

        @objc func handleTap() {
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
