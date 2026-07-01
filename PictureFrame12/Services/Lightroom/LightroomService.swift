import Foundation
import UIKit

final class LightroomService: PhotoProvider {
    let kind: PhotoSourceKind = .lightroom

    private let api: LightroomAPIClient
    private let auth: LightroomAuthService
    private var assetCatalogMap: [String: String] = [:]
    private let mapLock = NSLock()

    init(auth: LightroomAuthService) {
        self.auth = auth
        self.api = LightroomAPIClient(auth: auth)
    }

    func fetchAlbums(completion: @escaping (Result<[Album], Error>) -> Void) {
        guard auth.isAuthenticated else { completion(.failure(PhotoProviderError.notAuthenticated)); return }
        api.fetchCatalog { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let e): completion(.failure(e))
            case .success(let catalog):
                self.api.fetchAlbums(catalogID: catalog.id) { result2 in
                    switch result2 {
                    case .failure(let e): completion(.failure(e))
                    case .success(let lrAlbums):
                        let albums = lrAlbums.map { lrAlbum in
                            Album(id: "\(catalog.id)/\(lrAlbum.id)", title: lrAlbum.name,
                                  source: .lightroom, estimatedCount: nil)
                        }
                        completion(.success(albums))
                    }
                }
            }
        }
    }

    func fetchPhotos(in selection: AlbumSelection, completion: @escaping (Result<[FramePhoto], Error>) -> Void) {
        guard auth.isAuthenticated else { completion(.failure(PhotoProviderError.notAuthenticated)); return }
        let proceed: (String) -> Void = { [weak self] catalogID in
            guard let self = self else { return }
            self.api.fetchAssets(catalogID: catalogID, albumID: selection.albumID) { result in
                switch result {
                case .failure(let e): completion(.failure(e))
                case .success(let assets):
                    var photos: [FramePhoto] = []
                    var newMap: [String: String] = [:]
                    for asset in assets {
                        photos.append(FramePhoto(id: asset.id, source: .lightroom,
                                                  creationDate: asset.captureDate, aspectRatio: asset.aspectRatio))
                        newMap[asset.id] = catalogID
                    }
                    self.mapLock.lock()
                    for (k, v) in newMap { self.assetCatalogMap[k] = v }
                    self.mapLock.unlock()
                    completion(.success(photos))
                }
            }
        }
        if let catalogID = selection.catalogID { proceed(catalogID) }
        else {
            api.fetchCatalog { result in
                switch result {
                case .failure(let e): completion(.failure(e))
                case .success(let catalog): proceed(catalog.id)
                }
            }
        }
    }

    func loadImage(for photo: FramePhoto, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        mapLock.lock()
        let catalogID = assetCatalogMap[photo.id]
        mapLock.unlock()
        guard let catalogID = catalogID else { completion(nil); return }
        api.downloadImage(catalogID: catalogID, assetID: photo.id, targetSize: targetSize) { result in
            switch result {
            case .success(let image): completion(image)
            case .failure: completion(nil)
            }
        }
    }
}
