import Foundation

struct Album: Hashable {
    let id: String
    let title: String
    let source: PhotoSourceKind
    let estimatedCount: Int?
}

struct AlbumSelection: Codable, Hashable {
    var id: String { "\(source.rawValue):\(albumID)" }
    let source: PhotoSourceKind
    let albumID: String
    let title: String
    var catalogID: String?
}
