import Foundation

struct Album: Hashable {
    let id: String
    let title: String
    let source: PhotoSourceKind
    let estimatedCount: Int?
}

struct AlbumSelection: Codable, Hashable {
    var id: String { return "\(source.rawValue):\(albumID)" }
    let source: PhotoSourceKind
    let albumID: String
    let title: String
    var catalogID: String? = nil

    init(source: PhotoSourceKind, albumID: String, title: String, catalogID: String? = nil) {
        self.source = source
        self.albumID = albumID
        self.title = title
        self.catalogID = catalogID
    }
}
