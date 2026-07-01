import Foundation

enum CollageFitStyle: String, CaseIterable, Codable {
    case blurFill
    case aspect
    var displayName: String {
        switch self {
        case .blurFill: return "블러 배경"
        case .aspect:   return "비율 맞춤"
        }
    }
}

/// iOS 12 compatible settings store.
/// Replaces @Published with NotificationCenter posts.
final class SettingsStore {

    // MARK: - Selected Albums
    var selectedAlbums: [AlbumSelection] {
        didSet { save(selectedAlbums, key: "selectedAlbums")
                 post(.selectedAlbumsChanged) }
    }
    var folderBookmarks: [String: Data] {
        didSet { save(folderBookmarks, key: "folderBookmarks") }
    }

    // MARK: - Display Mode
    var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode")
                 post(.displayModeChanged) }
    }

    // MARK: - Slideshow Settings
    var slideInterval: TimeInterval {
        didSet { UserDefaults.standard.set(slideInterval, forKey: "slideInterval")
                 post(.slideshowSettingsChanged) }
    }
    var kenBurnsEnabled: Bool {
        didSet { UserDefaults.standard.set(kenBurnsEnabled, forKey: "kenBurnsEnabled")
                 post(.slideshowSettingsChanged) }
    }
    var kenBurnsIntensity: Double {
        didSet { UserDefaults.standard.set(kenBurnsIntensity, forKey: "kenBurnsIntensity")
                 post(.slideshowSettingsChanged) }
    }
    var slideTransition: SlideTransition {
        didSet { UserDefaults.standard.set(slideTransition.rawValue, forKey: "slideTransition")
                 post(.slideshowSettingsChanged) }
    }
    var selectedTransitions: [SlideTransition] {
        didSet { save(selectedTransitions.map(\.rawValue), key: "selectedTransitions")
                 post(.slideshowSettingsChanged) }
    }

    // MARK: - Collage Range
    var collageRangeMin: Int {
        didSet { UserDefaults.standard.set(collageRangeMin, forKey: "collageRangeMin")
                 post(.slideshowSettingsChanged) }
    }
    var collageRangeMax: Int {
        didSet { UserDefaults.standard.set(collageRangeMax, forKey: "collageRangeMax")
                 post(.slideshowSettingsChanged) }
    }
    var slideshowFitStyle: CollageFitStyle {
        didSet { UserDefaults.standard.set(slideshowFitStyle.rawValue, forKey: "slideshowFitStyle")
                 post(.slideshowSettingsChanged) }
    }

    var isSinglePhotoShow: Bool {
        min(collageRangeMin, collageRangeMax) == 1 && max(collageRangeMin, collageRangeMax) == 1
    }

    func collagePhotoCount(forScene scene: Int) -> Int {
        let lo = max(1, min(collageRangeMin, collageRangeMax))
        let hi = max(collageRangeMin, collageRangeMax)
        let span = hi - lo + 1
        guard span > 1 else { return lo }
        var x = UInt64(bitPattern: Int64(scene &+ 1))
        x = (x &* 0x9E3779B97F4A7C15) ^ (x >> 29)
        return lo + Int(x % UInt64(span))
    }

    // MARK: - Music
    var musicEnabled: Bool {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
                 post(.musicSettingsChanged) }
    }
    var musicVolume: Double {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
                 post(.musicSettingsChanged) }
    }
    var musicTracks: [String] {
        didSet { save(musicTracks, key: "musicTracks"); post(.musicSettingsChanged) }
    }
    var musicFolderTracks: [String] {
        didSet { save(musicFolderTracks, key: "musicFolderTracks"); post(.musicSettingsChanged) }
    }
    var musicFolderName: String? {
        didSet { UserDefaults.standard.set(musicFolderName, forKey: "musicFolderName")
                 post(.musicSettingsChanged) }
    }
    static let maxIndividualTracks = 10

    // MARK: - Overlay / UI
    var showClock: Bool {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock")
                 post(.overlaySettingsChanged) }
    }
    var showWeather: Bool {
        didSet { UserDefaults.standard.set(showWeather, forKey: "showWeather")
                 post(.overlaySettingsChanged) }
    }
    var alwaysShowControls: Bool {
        didSet { UserDefaults.standard.set(alwaysShowControls, forKey: "alwaysShowControls")
                 post(.overlaySettingsChanged) }
    }
    var appLanguage: String {
        didSet { UserDefaults.standard.set(appLanguage, forKey: "appLanguage") }
    }

    static let musicDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    var musicURLs: [URL] {
        (musicTracks + musicFolderTracks).map { Self.musicDirectory.appendingPathComponent($0) }
    }
    var hasAnyMusic: Bool { !musicTracks.isEmpty || !musicFolderTracks.isEmpty }

    // MARK: - Init
    init() {
        let d = UserDefaults.standard
        selectedAlbums  = Self.load(key: "selectedAlbums") ?? []
        folderBookmarks = Self.load(key: "folderBookmarks") ?? [:]
        displayMode     = DisplayMode(rawValue: d.string(forKey: "displayMode") ?? "") ?? .slideshow
        slideInterval   = d.double(forKey: "slideInterval").nonZero ?? AppConfig.defaultSlideInterval
        kenBurnsEnabled   = d.object(forKey: "kenBurnsEnabled")   as? Bool   ?? true
        kenBurnsIntensity = d.object(forKey: "kenBurnsIntensity") as? Double ?? 1.0
        slideTransition = SlideTransition(rawValue: d.string(forKey: "slideTransition") ?? "") ?? .crossfade
        let savedT: [String] = Self.load(key: "selectedTransitions") ?? []
        let restored = savedT.compactMap { SlideTransition(rawValue: $0) }
        selectedTransitions = restored.isEmpty ? [.crossfade, .slide, .zoom] : restored
        collageRangeMin = d.integer(forKey: "collageRangeMin").nonZero ?? 1
        collageRangeMax = d.integer(forKey: "collageRangeMax").nonZero ?? 4
        slideshowFitStyle = CollageFitStyle(rawValue: d.string(forKey: "slideshowFitStyle") ?? "") ?? .blurFill
        musicEnabled    = d.object(forKey: "musicEnabled")  as? Bool   ?? false
        musicVolume     = d.object(forKey: "musicVolume")   as? Double ?? 0.6
        musicTracks     = Self.load(key: "musicTracks")     ?? []
        musicFolderTracks = Self.load(key: "musicFolderTracks") ?? []
        musicFolderName = d.string(forKey: "musicFolderName")
        showClock       = d.object(forKey: "showClock")     as? Bool ?? false
        showWeather     = d.object(forKey: "showWeather")   as? Bool ?? true
        alwaysShowControls = d.object(forKey: "alwaysShowControls") as? Bool ?? true
        appLanguage     = d.string(forKey: "appLanguage") ?? "ko"
    }

    // MARK: - Helpers
    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: self)
    }
    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
    private static func load<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func addAlbum(_ selection: AlbumSelection) {
        guard !selectedAlbums.contains(selection) else { return }
        selectedAlbums.append(selection)
    }
    func removeAlbum(_ selection: AlbumSelection) {
        selectedAlbums.removeAll { $0 == selection }
        if selection.source == .folder { folderBookmarks[selection.albumID] = nil }
    }
    func addFolderAlbum(url: URL) throws {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let albumID = UUID().uuidString
        folderBookmarks[albumID] = bookmark
        addAlbum(AlbumSelection(source: .folder, albumID: albumID, title: url.lastPathComponent))
    }
}

private extension Double { var nonZero: Double? { self == 0 ? nil : self } }
private extension Int    { var nonZero: Int?    { self == 0 ? nil : self } }
