import SwiftUI
import UIKit

enum PhotoFaceStoreError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "That image could not be opened."
        case .encodingFailed:
            "That image could not be prepared for the timer face."
        }
    }
}

final class PhotoFaceStore: ObservableObject {
    @Published private(set) var image: UIImage?

    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = applicationSupport.appendingPathComponent("PhotoFace", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent("photo.jpg")
        image = UIImage(contentsOfFile: fileURL.path)
    }

    func save(data: Data) throws {
        guard let source = UIImage(data: data) else {
            throw PhotoFaceStoreError.unreadableImage
        }

        let prepared = preparedImage(from: source)
        guard let encoded = prepared.jpegData(compressionQuality: 0.88) else {
            throw PhotoFaceStoreError.encodingFailed
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try encoded.write(to: fileURL, options: .atomic)
        image = prepared
    }

    func remove() throws {
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        image = nil
    }

    private func preparedImage(from source: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2_048
        let longestEdge = max(source.size.width, source.size.height)
        let scale = longestEdge > 0 ? min(1, maxDimension / longestEdge) : 1
        let size = CGSize(
            width: max(1, (source.size.width * scale).rounded()),
            height: max(1, (source.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
