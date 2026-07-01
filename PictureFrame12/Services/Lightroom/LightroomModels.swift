import Foundation

struct LightroomCatalog: Decodable { let id: String }

struct LightroomAlbumList: Decodable { let resources: [LightroomAlbum] }

struct LightroomAlbum: Decodable {
    let id: String
    let subtype: String?
    let payload: Payload?
    struct Payload: Decodable { let name: String? }
    var name: String { payload?.name ?? "제목 없음" }
}

struct LightroomAssetList: Decodable { let resources: [LightroomAlbumAssetRef] }
struct LightroomAlbumAssetRef: Decodable { let asset: LightroomAsset }

struct LightroomAsset: Decodable {
    let id: String
    let payload: Payload?
    struct Payload: Decodable {
        let captureDate: String?
        let develop: Develop?
        let importSource: ImportSource?
        struct Develop: Decodable { let croppedWidth: Double?; let croppedHeight: Double? }
        struct ImportSource: Decodable { let originalWidth: Double?; let originalHeight: Double? }
    }
    var captureDate: Date? {
        guard let raw = payload?.captureDate else { return nil }
        return ISO8601DateFormatter().date(from: raw) ?? LightroomAsset.fallbackFormatter.date(from: raw)
    }
    var aspectRatio: CGFloat? {
        if let w = payload?.develop?.croppedWidth, let h = payload?.develop?.croppedHeight, h > 0 { return CGFloat(w/h) }
        if let w = payload?.importSource?.originalWidth, let h = payload?.importSource?.originalHeight, h > 0 { return CGFloat(w/h) }
        return nil
    }
    private static let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

private struct IMSTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
