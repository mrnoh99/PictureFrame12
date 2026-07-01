import Foundation
import UIKit

final class LightroomAPIClient {
    private let auth: LightroomAuthService
    private let session: URLSession

    init(auth: LightroomAuthService) {
        self.auth = auth
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func fetchCatalog(completion: @escaping (Result<LightroomCatalog, Error>) -> Void) {
        get(path: "/catalog") { result in
            completion(result.flatMap { Self.stripAndDecode($0, as: LightroomCatalog.self) })
        }
    }

    func fetchAlbums(catalogID: String, completion: @escaping (Result<[LightroomAlbum], Error>) -> Void) {
        get(path: "/catalogs/\(catalogID)/albums", params: ["subtype": "collection", "limit": "100"]) { result in
            completion(result.flatMap { Self.stripAndDecode($0, as: LightroomAlbumList.self).map { $0.resources } })
        }
    }

    func fetchAssets(catalogID: String, albumID: String, completion: @escaping (Result<[LightroomAsset], Error>) -> Void) {
        get(path: "/catalogs/\(catalogID)/albums/\(albumID)/assets",
            params: ["limit": "100", "embed": "asset"]) { result in
            completion(result.flatMap { Self.stripAndDecode($0, as: LightroomAssetList.self).map { $0.resources.map(\.asset) } })
        }
    }

    func downloadImage(catalogID: String, assetID: String, targetSize: CGSize,
                       completion: @escaping (Result<UIImage, Error>) -> Void) {
        let scale = UIScreen.main.scale
        let maxDim = max(targetSize.width, targetSize.height) * scale
        let size: String
        switch maxDim {
        case ..<700: size = "640"
        case 700..<1600: size = "1280"
        default: size = "2048"
        }
        guard let url = URL(string: "\(AppConfig.Lightroom.apiBaseURL)/catalogs/\(catalogID)/assets/\(assetID)/renditions/\(size)") else {
            completion(.failure(PhotoProviderError.imageUnavailable)); return
        }
        auth.validAccessToken { token, error in
            if let error = error { completion(.failure(error)); return }
            guard let token = token else { completion(.failure(PhotoProviderError.notAuthenticated)); return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(AppConfig.Lightroom.clientID, forHTTPHeaderField: "X-API-Key")
            self.session.dataTask(with: req) { data, response, error in
                if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
                guard let data = data,
                      let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async { completion(.failure(PhotoProviderError.imageUnavailable)) }; return
                }
                DispatchQueue.main.async { completion(.success(image)) }
            }.resume()
        }
    }

    private func get(path: String, params: [String: String] = [:],
                     completion: @escaping (Result<Data, Error>) -> Void) {
        guard var components = URLComponents(string: AppConfig.Lightroom.apiBaseURL + path) else {
            completion(.failure(PhotoProviderError.server("잘못된 URL"))); return
        }
        if !params.isEmpty { components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components.url else { completion(.failure(PhotoProviderError.server("URL 생성 실패"))); return }

        auth.validAccessToken { [weak self] token, error in
            guard let self = self else { return }
            if let error = error { completion(.failure(error)); return }
            guard let token = token else { completion(.failure(PhotoProviderError.notAuthenticated)); return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(AppConfig.Lightroom.clientID, forHTTPHeaderField: "X-API-Key")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            self.session.dataTask(with: request) { data, response, error in
                if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
                guard let data = data, let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    DispatchQueue.main.async { completion(.failure(PhotoProviderError.server("HTTP: \(body)"))) }; return
                }
                DispatchQueue.main.async { completion(.success(data)) }
            }.resume()
        }
    }

    private static func stripAndDecode<T: Decodable>(_ data: Data, as type: T.Type) -> Result<T, Error> {
        var cleaned = data
        if let raw = String(data: data, encoding: .utf8), raw.hasPrefix("while") {
            let stripped = raw.drop(while: { $0 != "{" && $0 != "[" })
            cleaned = Data(stripped.utf8)
        }
        return Result { try JSONDecoder().decode(type, from: cleaned) }
    }
}
