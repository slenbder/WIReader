import SwiftUI
import UIKit

// Styling parameters — replace with @AppStorage values in Phase 2.5
struct TextReaderStyle {
    var bodyFontSize: CGFloat = 17
    var titleFontSize: CGFloat = 22
    var lineSpacing: CGFloat = 6
    var paragraphSpacing: CGFloat = 12
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
    var onProgressUpdate: (Double) -> Bool
    var onFlushProgress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgressUpdate: onProgressUpdate, onFlushProgress: onFlushProgress)
    }

    func makeUIView(context: Context) -> PositionRestoringTextView {
        let textView = PositionRestoringTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.backgroundColor = .systemBackground
        textView.delegate = context.coordinator
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

        let textChanged = context.coordinator.lastText != text
        let tokenChanged = context.coordinator.lastRestoreToken != restoreToken

        if textChanged {
            // isRestoringPosition prevents UITextView's internal offset reset
            // from firing scrollViewDidScroll and overwriting saved progress with 0
            context.coordinator.isRestoringPosition = true
            context.coordinator.lastText = text
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
            titleStyle.paragraphSpacing = style.paragraphSpacing * 2
            result.append(NSAttributedString(string: title + "\n\n", attributes: [
                .font: UIFont.boldSystemFont(ofSize: style.titleFontSize),
                .paragraphStyle: titleStyle
            ]))
        }

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = style.lineSpacing
        bodyStyle.paragraphSpacing = style.paragraphSpacing
        result.append(NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: style.bodyFontSize),
            .paragraphStyle: bodyStyle
        ]))

        return result
    }
}

// MARK: - Coordinator

extension TextReaderView {
    final class Coordinator: NSObject, UITextViewDelegate {
        var onProgressUpdate: (Double) -> Bool
        var onFlushProgress: () -> Void
        var lastText: String?
        var lastRestoreToken: Int = -1
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

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            onFlushProgress()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { onFlushProgress() }
        }
    }
}
