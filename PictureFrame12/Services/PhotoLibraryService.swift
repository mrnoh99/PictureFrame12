import Foundation
import Photos
import UIKit

final class PhotoLibraryService: PhotoProvider {
    let kind: PhotoSourceKind = .photoLibrary

    private let imageManager = PHCachingImageManager()
    private var assetIndex: [String: PHAsset] = [:]
    private let indexLock = NSLock()

    // MARK: - Authorization (iOS 12 API - no `for:` parameter)

    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        let current = PHPhotoLibrary.authorizationStatus()
        if current == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { completion(status) }
            }
        } else {
            completion(current)
        }
    }

    private func ensureAuthorized(completion: @escaping (Error?) -> Void) {
        requestAuthorization { status in
            if status == .authorized {
                completion(nil)
            } else {
                completion(PhotoProviderError.notAuthorized)
            }
        }
    }

    // MARK: - Albums

    func fetchAlbums(completion: @escaping (Result<[Album], Error>) -> Void) {
        ensureAuthorized { error in
            if let error = error { completion(.failure(error)); return }
            var albums: [Album] = []
            let userCollections = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .any, options: nil)
            userCollections.enumerateObjects { collection, _, _ in
                albums.append(self.makeAlbum(from: collection))
            }
            let smartSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumUserLibrary, .smartAlbumFavorites, .smartAlbumRecentlyAdded
            ]
            for subtype in smartSubtypes {
                let smart = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum, subtype: subtype, options: nil)
                smart.enumerateObjects { collection, _, _ in
                    albums.append(self.makeAlbum(from: collection))
                }
            }
            completion(.success(albums.filter { ($0.estimatedCount ?? 0) > 0 }))
        }
    }

    private func makeAlbum(from collection: PHAssetCollection) -> Album {
        let count = collection.estimatedAssetCount == NSNotFound ? nil : collection.estimatedAssetCount
        return Album(id: collection.localIdentifier,
                     title: collection.localizedTitle ?? "제목 없음",
                     source: .photoLibrary,
                     estimatedCount: count)
    }

    // MARK: - Photos

    func fetchPhotos(in selection: AlbumSelection, completion: @escaping (Result<[FramePhoto], Error>) -> Void) {
        ensureAuthorized { error in
            if let error = error { completion(.failure(error)); return }
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [selection.albumID], options: nil)
            guard let collection = collections.firstObject else {
                completion(.failure(PhotoProviderError.albumNotFound)); return
            }
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            var photos: [FramePhoto] = []
            photos.reserveCapacity(assets.count)
            var newIndex: [String: PHAsset] = [:]
            assets.enumerateObjects { asset, _, _ in
                let ratio: CGFloat? = asset.pixelHeight > 0
                    ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight) : nil
                photos.append(FramePhoto(id: asset.localIdentifier,
                                         source: .photoLibrary,
                                         creationDate: asset.creationDate,
                                         aspectRatio: ratio))
                newIndex[asset.localIdentifier] = asset
            }
            self.indexLock.lock()
            for (k, v) in newIndex { self.assetIndex[k] = v }
            self.indexLock.unlock()
            completion(.success(photos))
        }
    }

    // MARK: - Image Load

    func loadImage(for photo: FramePhoto, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        indexLock.lock()
        let cached = assetIndex[photo.id]
        indexLock.unlock()

        let finalize: (PHAsset) -> Void = { [weak self] asset in
            guard let self = self else { completion(nil); return }
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            let scale = UIScreen.main.scale
            let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
            self.imageManager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded { return }
                DispatchQueue.main.async { completion(image) }
            }
        }

        if let asset = cached {
            finalize(asset)
        } else {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [photo.id], options: nil)
            guard let asset = result.firstObject else { completion(nil); return }
            indexLock.lock(); assetIndex[photo.id] = asset; indexLock.unlock()
            finalize(asset)
        }
    }
}
