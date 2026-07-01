import Foundation

enum DisplayMode: String, CaseIterable, Codable {
    case slideshow
    case collage
    case grid

    static var selectableCases: [DisplayMode] { [.slideshow, .grid] }

    var displayName: String {
        switch self {
        case .slideshow: return "슬라이드쇼"
        case .collage:   return "콜라주"
        case .grid:      return "그리드"
        }
    }
}
