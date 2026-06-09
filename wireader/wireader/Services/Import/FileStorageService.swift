import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class FileStorageService {

    // MARK: - Storage directory

    private func storageDirectory() async -> URL {
        // ubiquityContainerURL can block — must NOT be called on the main thread
        let icloudBase = await Task.detached(priority: .utility) {
            FileManager.default.url(forUbiquityContainerIdentifier: AppConstants.iCloudContainerID)
        }.value

        let base: URL
        if let icloudBase {
            base = icloudBase.appendingPathComponent("Documents/Books", isDirectory: true)
            AppLogger.general.info("FileStorage: using iCloud — \(base.path)")
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            base = docs.appendingPathComponent("Books", isDirectory: true)
            AppLogger.general.info("FileStorage: iCloud unavailable, using local — \(base.path)")
        }

        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    // MARK: - Public API

    func save(from sourceURL: URL) async throws -> String {
        let ext = sourceURL.pathExtension
        let fileName = UUID().uuidString + (ext.isEmpty ? "" : "." + ext)
        let destination = await storageDirectory().appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw WIReaderError.storageError("Copy failed: \(error.localizedDescription)")
        }
        return fileName
    }

    func url(for fileName: String) async -> URL? {
        let candidate = await storageDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    func delete(fileName: String) async throws {
        let target = await storageDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.removeItem(at: target)
        } catch {
            throw WIReaderError.storageError("Delete failed: \(error.localizedDescription)")
        }
    }
}
