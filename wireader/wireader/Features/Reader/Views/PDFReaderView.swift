import SwiftUI
import PDFKit

final class PositionRestoringPDFView: PDFView {
    var pendingRestorePosition: Double?
    var onRestoreReady: ((Double) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0, let position = pendingRestorePosition else { return }
        pendingRestorePosition = nil
        onRestoreReady?(position)
    }
}

struct PDFReaderView: UIViewRepresentable {
    let fileURL: URL
    let positionInChapter: Double
    let restoreToken: Int
    var onProgressUpdate: (Double) -> Bool
    var onFlushProgress: () -> Void
    var onTap: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgressUpdate: onProgressUpdate, onFlushProgress: onFlushProgress)
    }

    func makeUIView(context: Context) -> PositionRestoringPDFView {
        let pdfView = PositionRestoringPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        context.coordinator.pdfView = pdfView
        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapRecognizer)
        pdfView.onRestoreReady = { [weak pdfView, weak coordinator = context.coordinator] position in
            guard let pdfView, let coordinator else { return }
            coordinator.restore(pdfView, position: position)
        }
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateUIView(_ pdfView: PositionRestoringPDFView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onFlushProgress = onFlushProgress
        context.coordinator.onTap = onTap

        let urlChanged = context.coordinator.loadedURL != fileURL
        let tokenChanged = context.coordinator.restoreToken != restoreToken

        if urlChanged {
            context.coordinator.loadedURL = fileURL
            context.coordinator.beginInitialRestore()
            pdfView.document = PDFDocument(url: fileURL)
        }

        guard tokenChanged || urlChanged else { return }
        context.coordinator.restoreToken = restoreToken
        pdfView.pendingRestorePosition = positionInChapter
        pdfView.setNeedsLayout()
    }

    static func dismantleUIView(_ pdfView: PositionRestoringPDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }
}

extension PDFReaderView {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onProgressUpdate: (Double) -> Bool
        var onFlushProgress: () -> Void
        var onTap: () -> Void = {}
        weak var pdfView: PDFView?
        var loadedURL: URL?
        var restoreToken: Int = -1
        private var isRestoring = false
        private var initialRestoreCompleted = false

        init(onProgressUpdate: @escaping (Double) -> Bool, onFlushProgress: @escaping () -> Void) {
            self.onProgressUpdate = onProgressUpdate
            self.onFlushProgress = onFlushProgress
        }

        func beginInitialRestore() {
            initialRestoreCompleted = false
            isRestoring = true
        }

        func restore(_ pdfView: PDFView, position: Double) {
            defer {
                isRestoring = false
                initialRestoreCompleted = true
            }

            guard let document = pdfView.document, document.pageCount > 0 else { return }

            let clampedPosition = min(max(position, 0.0), 1.0)
            let rawIndex = clampedPosition == 0
                ? 0
                : Int(ceil(clampedPosition * Double(document.pageCount))) - 1
            let pageIndex = min(max(rawIndex, 0), document.pageCount - 1)
            guard let page = document.page(at: pageIndex) else { return }

            pdfView.go(to: page)
        }

        @objc func pageChanged(_ notification: Notification) {
            guard initialRestoreCompleted,
                  !isRestoring,
                  let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  document.pageCount > 0,
                  let page = pdfView.currentPage
            else { return }

            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return }
            let currentPageNumber = min(max(pageIndex + 1, 1), document.pageCount)
            let position = min(max(Double(currentPageNumber) / Double(document.pageCount), 0.0), 1.0)
            _ = onProgressUpdate(position)
            onFlushProgress()
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
