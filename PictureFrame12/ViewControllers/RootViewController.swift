import UIKit

/// Root container: shows WelcomeViewController when no albums selected, else FrameContainerViewController.
final class RootViewController: UIViewController {

    private let settings: SettingsStore
    private let audioPlayer: AudioPlayerService
    private let lightroomAuth: LightroomAuthService
    private let viewModel: FrameViewModel

    private var currentChild: UIViewController?
    private let settingsButton = UIButton(type: .system)
    private var controlsHideTimer: Timer?

    init(settings: SettingsStore,
         audioPlayer: AudioPlayerService,
         lightroomAuth: LightroomAuthService,
         viewModel: FrameViewModel) {
        self.settings = settings
        self.audioPlayer = audioPlayer
        self.lightroomAuth = lightroomAuth
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSettingsButton()
        showAppropriateChild(animated: false)
        syncMusic()

        NotificationCenter.default.addObserver(self, selector: #selector(onSelectedAlbumsChanged),
                                               name: .selectedAlbumsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onMusicSettingsChanged),
                                               name: .musicSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onOverlayChanged),
                                               name: .overlaySettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAppActive),
                                               name: .appDidBecomeActive, object: nil)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Settings Button

    private func setupSettingsButton() {
        settingsButton.setTitle("⚙", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        settingsButton.setTitleColor(UIColor.white.withAlphaComponent(0.8), for: .normal)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        updateControlsVisibility()
    }

    private func updateControlsVisibility() {
        settingsButton.isHidden = !settings.alwaysShowControls
    }

    @objc private func handleTap() {
        guard !settings.alwaysShowControls else { return }
        settingsButton.isHidden = false
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.settingsButton.isHidden = true
        }
    }

    @objc private func openSettings() {
        let vc = SettingsViewController(settings: settings, audioPlayer: audioPlayer, lightroomAuth: lightroomAuth)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    // MARK: - Child Management

    private func showAppropriateChild(animated: Bool) {
        if settings.selectedAlbums.isEmpty {
            showChild(WelcomeViewController(settings: settings), animated: animated)
        } else {
            let frameVC = FrameContainerViewController(settings: settings, viewModel: viewModel)
            showChild(frameVC, animated: animated)
        }
    }

    private func showChild(_ child: UIViewController, animated: Bool) {
        let old = currentChild
        currentChild = child
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(child.view, at: 0)
        child.didMove(toParent: self)
        view.bringSubviewToFront(settingsButton)

        if let old = old, animated {
            UIView.animate(withDuration: 0.4, animations: { old.view.alpha = 0 }) { _ in
                old.willMove(toParent: nil)
                old.view.removeFromSuperview()
                old.removeFromParent()
            }
        } else {
            old?.willMove(toParent: nil)
            old?.view.removeFromSuperview()
            old?.removeFromParent()
        }
    }

    // MARK: - Notifications

    @objc private func onSelectedAlbumsChanged() {
        DispatchQueue.main.async { self.showAppropriateChild(animated: true) }
    }

    @objc private func onMusicSettingsChanged() { syncMusic() }

    @objc private func onOverlayChanged() { updateControlsVisibility() }

    @objc private func onAppActive() { syncMusic() }

    private func syncMusic() {
        if settings.musicEnabled && settings.hasAnyMusic {
            audioPlayer.setTracks(settings.musicURLs)
            audioPlayer.setVolume(settings.musicVolume)
            audioPlayer.start()
        } else {
            audioPlayer.stop()
        }
    }
}
