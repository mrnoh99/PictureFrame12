import Foundation
import UIKit

struct FramePhoto: Hashable {
    let id: String
    let source: PhotoSourceKind
    let creationDate: Date?
    let aspectRatio: CGFloat?

    static func == (lhs: FramePhoto, rhs: FramePhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PhotoSourceKind: String, Codable, Hashable {
    case photoLibrary
    case lightroom
    case folder

    var displayName: String {
        switch self {
        case .photoLibrary: return "iOS 사진"
        case .lightroom:    return "Lightroom"
        case .folder:       return "폴더"
        }
    }
}
