import UIKit

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let selectedAlbumsChanged = Notification.Name("selectedAlbumsChanged")
    static let musicSettingsChanged = Notification.Name("musicSettingsChanged")
    static let displayModeChanged = Notification.Name("displayModeChanged")
    static let slideshowSettingsChanged = Notification.Name("slideshowSettingsChanged")
    static let overlaySettingsChanged = Notification.Name("overlaySettingsChanged")
    static let photosReloaded = Notification.Name("photosReloaded")
    static let photosLoadFailed = Notification.Name("photosLoadFailed")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var settings: SettingsStore!
    private var audioPlayer: AudioPlayerService!
    private var lightroomAuth: LightroomAuthService!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = true

        settings = SettingsStore()
        audioPlayer = AudioPlayerService()
        lightroomAuth = LightroomAuthService()

        let photoLib = PhotoLibraryService()
        let lightroomSvc = LightroomService(auth: lightroomAuth)
        let folderSvc = FolderPhotoService(settings: settings)
        let vm = FrameViewModel(settings: settings,
                                photoLib: photoLib,
                                lightroom: lightroomSvc,
                                folder: folderSvc)

        let rootVC = RootViewController(settings: settings,
                                        audioPlayer: audioPlayer,
                                        lightroomAuth: lightroomAuth,
                                        viewModel: vm)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        lightroomAuth.handleRedirect(url: url)
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }
}
