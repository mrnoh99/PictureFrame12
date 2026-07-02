import Foundation
import UIKit

// Swift 4.2 compatible Result type (added to stdlib in Swift 5.0)
enum Result<T, E: Error> {
    case success(T)
    case failure(E)
}

extension Result where E == Error {
    init(catching body: () throws -> T) {
        do { self = .success(try body()) }
        catch { self = .failure(error) }
    }
}

extension Result {
    func map<U>(_ transform: (T) -> U) -> Result<U, E> {
        switch self {
        case .success(let value): return .success(transform(value))
        case .failure(let error): return .failure(error)
        }
    }

    func flatMap<U>(_ transform: (T) -> Result<U, E>) -> Result<U, E> {
        switch self {
        case .success(let value): return transform(value)
        case .failure(let error): return .failure(error)
        }
    }
}

protocol PhotoProvider: AnyObject {
    var kind: PhotoSourceKind { get }
    func fetchAlbums(completion: @escaping (Result<[Album], Error>) -> Void)
    func fetchPhotos(in selection: AlbumSelection, completion: @escaping (Result<[FramePhoto], Error>) -> Void)
    func loadImage(for photo: FramePhoto, targetSize: CGSize, completion: @escaping (UIImage?) -> Void)
}

enum PhotoProviderError: LocalizedError {
    case notAuthorized
    case notConfigured
    case notAuthenticated
    case albumNotFound
    case imageUnavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:      return "사진 보관함 접근 권한이 없습니다."
        case .notConfigured:      return "Lightroom 자격 증명이 설정되지 않았습니다."
        case .notAuthenticated:   return "Lightroom 로그인이 필요합니다."
        case .albumNotFound:      return "앨범을 찾을 수 없습니다."
        case .imageUnavailable:   return "이미지를 불러올 수 없습니다."
        case .server(let msg):    return "서버 오류: \(msg)"
        }
    }
}
