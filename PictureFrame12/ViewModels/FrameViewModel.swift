import Foundation
import UIKit

/// Delegate informed of photo/state changes.
protocol FrameViewModelDelegate: AnyObject {
    func viewModelDidReloadPhotos(_ vm: FrameViewModel)
    func viewModelDidFailLoading(_ vm: FrameViewModel, error: Error)
    func viewModelDidAdvance(_ vm: FrameViewModel)
}

/// iOS 12 compatible FrameViewModel.
/// Replaces @MainActor/@Published/async-await with DispatchQueue + delegate callbacks.
final class FrameViewModel {
    weak var delegate: FrameViewModelDelegate?

    private(set) var photos: [FramePhoto] = []
    private(set) var currentIndex: Int = 0
    private(set) var isLoading = false

    private let settings: SettingsStore
    private let photoLib: PhotoLibraryService
    private let lightroom: LightroomService
    private let folder: FolderPhotoService

    private var slideTimer: Timer?
    private var prefetchOps: [String: Operation] = [:]
    private let prefetchQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 3
        q.qualityOfService = .utility
        return q
    }()

    init(settings: SettingsStore,
         photoLib: PhotoLibraryService,
         lightroom: LightroomService,
         folder: FolderPhotoService) {
        self.settings = settings
        self.photoLib = photoLib
        self.lightroom = lightroom
        self.folder = folder

        NotificationCenter.default.addObserver(
            self, selector: #selector(onAlbumsChanged),
            name: .selectedAlbumsChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        slideTimer?.invalidate()
    }

    @objc private func onAlbumsChanged() {
        // Debounce: cancel pending reload, fire after 0.5s
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(reload), object: nil)
        perform(#selector(reload), with: nil, afterDelay: 0.5)
    }

    // MARK: - Load

    @objc func reload() {
        guard !settings.selectedAlbums.isEmpty else {
            photos = []
            DispatchQueue.main.async { self.delegate?.viewModelDidReloadPhotos(self) }
            return
        }
        isLoading = true
        let selections = settings.selectedAlbums
        var allPhotos: [FramePhoto] = []
        var remaining = selections.count
        let lock = NSLock()
        var firstError: Error?

        for selection in selections {
            provider(for: selection.source).fetchPhotos(in: selection) { [weak self] result in
                guard let self = self else { return }
                lock.lock()
                switch result {
                case .success(let fetched): allPhotos.append(contentsOf: fetched)
                case .failure(let e): if firstError == nil { firstError = e }
                }
                remaining -= 1
                let done = remaining == 0
                lock.unlock()
                if done {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.prefetchQueue.cancelAllOperations()
                        self.prefetchOps.removeAll()
                        self.photos = allPhotos.shuffled()
                        self.currentIndex = 0
                        if let error = firstError {
                            self.delegate?.viewModelDidFailLoading(self, error: error)
                        } else {
                            self.delegate?.viewModelDidReloadPhotos(self)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Slide Timer

    func startSlideTimer(step: Int = 1) {
        stopSlideTimer()
        guard photos.count > 1 else { return }
        slideTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: true) { [weak self] _ in
            self?.advance(by: step)
        }
    }

    func startCollageTimer() {
        stopSlideTimer()
        guard photos.count > 1 else { return }
        slideTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let step = self.settings.collagePhotoCount(forScene: self.currentIndex)
            self.advance(by: max(1, step))
        }
    }

    func stopSlideTimer() { slideTimer?.invalidate(); slideTimer = nil }

    func advance(by step: Int = 1) {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex + step) % photos.count
        delegate?.viewModelDidAdvance(self)
    }

    func previous() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex - 1 + photos.count) % photos.count
        delegate?.viewModelDidAdvance(self)
    }

    // MARK: - Image Load

    private func provider(for source: PhotoSourceKind) -> PhotoProvider {
        switch source {
        case .photoLibrary: return photoLib
        case .lightroom:    return lightroom
        case .folder:       return folder
        }
    }

    func loadImage(for photo: FramePhoto, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let size = clampToScreen(targetSize)
        if let cached = ImageCache.shared.memoryImage(for: photo.id, size: size) {
            completion(cached); return
        }
        ImageCache.shared.diskImage(for: photo.id, size: size) { [weak self] disk in
            guard let self = self else { return }
            if let disk = disk {
                ImageCache.shared.storeMemory(disk, for: photo.id, size: size)
                completion(disk); return
            }
            self.provider(for: photo.source).loadImage(for: photo, targetSize: size) { image in
                if let image = image { ImageCache.shared.store(image, for: photo.id, size: size) }
                completion(image)
            }
        }
    }

    func cachedImage(for photo: FramePhoto, targetSize: CGSize) -> UIImage? {
        ImageCache.shared.memoryImage(for: photo.id, size: clampToScreen(targetSize))
    }

    private func clampToScreen(_ size: CGSize) -> CGSize {
        let screen = UIScreen.main.bounds.size
        let w = size.width > 0 ? min(size.width, screen.width) : screen.width
        let h = size.height > 0 ? min(size.height, screen.height) : screen.height
        return CGSize(width: w, height: h)
    }

    // MARK: - Prefetch

    func prefetchUpcoming(count: Int = 3, targetSize: CGSize) {
        guard !photos.isEmpty, targetSize.width > 0 else { return }
        for offset in 1...count {
            let idx = (currentIndex + offset) % photos.count
            let photo = photos[idx]
            let id = photo.id
            if ImageCache.shared.memoryImage(for: id, size: targetSize) != nil { continue }
            if prefetchOps[id] != nil { continue }
            let op = BlockOperation { [weak self] in
                guard let self = self else { return }
                let sem = DispatchSemaphore(value: 0)
                self.loadImage(for: photo, targetSize: targetSize) { _ in sem.signal() }
                sem.wait()
            }
            prefetchOps[id] = op
            op.completionBlock = { [weak self] in self?.prefetchOps[id] = nil }
            prefetchQueue.addOperation(op)
        }
    }

    // MARK: - Collage Batch

    func collageBatch(count: Int) -> [FramePhoto] {
        guard !photos.isEmpty else { return [] }
        let n = min(count, photos.count)
        return (0..<n).map { photos[(currentIndex + $0) % photos.count] }
    }
}
