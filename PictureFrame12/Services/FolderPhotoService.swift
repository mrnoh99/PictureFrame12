import Foundation
import UIKit
import ImageIO

final class FolderPhotoService: PhotoProvider {
    let kind: PhotoSourceKind = .folder

    private let settings: SettingsStore
    private var activeFolders: [String: URL] = [:]
    private let lock = NSLock()

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"
    ]

    init(settings: SettingsStore) { self.settings = settings }

    deinit { for url in activeFolders.values { url.stopAccessingSecurityScopedResource() } }

    func fetchAlbums(completion: @escaping (Result<[Album], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchPhotos(in selection: AlbumSelection, completion: @escaping (Result<[FramePhoto], Error>) -> Void) {
        guard let folder = resolveFolder(for: selection) else {
            completion(.failure(PhotoProviderError.albumNotFound)); return
        }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []
        let photos = urls
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .map { url -> FramePhoto in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return FramePhoto(id: url.absoluteString, source: .folder,
                                  creationDate: date, aspectRatio: Self.aspectRatio(of: url))
            }
        completion(.success(photos))
    }

    func loadImage(for photo: FramePhoto, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let url = URL(string: photo.id) else { DispatchQueue.main.async { completion(nil) }; return }
            let maxDim = max(targetSize.width, targetSize.height) * 2
            let image = Self.downsampledImage(at: url, maxPixel: maxDim > 0 ? maxDim : 2048)
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func resolveFolder(for selection: AlbumSelection) -> URL? {
        lock.lock(); defer { lock.unlock() }
        if let cached = activeFolders[selection.albumID] { return cached }
        guard let data = settings.folderBookmarks[selection.albumID] else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        activeFolders[selection.albumID] = url
        return url
    }

    private static func aspectRatio(of url: URL) -> CGFloat? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat, h > 0 else { return nil }
        return w / h
    }

    private static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
