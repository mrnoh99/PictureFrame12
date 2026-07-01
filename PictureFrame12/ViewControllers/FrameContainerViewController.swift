import UIKit

/// Hosts SlideshowViewController or GridGalleryViewController based on settings.displayMode.
final class FrameContainerViewController: UIViewController, FrameViewModelDelegate {
    private let settings: SettingsStore
    private let viewModel: FrameViewModel
    private var currentDisplayVC: UIViewController?
    private let clockView = ClockOverlayView()

    init(settings: SettingsStore, viewModel: FrameViewModel) {
        self.settings = settings
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        viewModel.delegate = self

        setupClockOverlay()
        viewModel.reload()

        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayModeChanged),
                                               name: .displayModeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSlideshowSettingsChanged),
                                               name: .slideshowSettingsChanged, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupClockOverlay() {
        clockView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clockView)
        NSLayoutConstraint.activate([
            clockView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            clockView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            clockView.topAnchor.constraint(equalTo: view.topAnchor),
            clockView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        clockView.isHidden = !settings.showClock
        if settings.showClock { clockView.startClock() }
    }

    private func showDisplayVC(animated: Bool = false) {
        let newVC: UIViewController
        switch settings.displayMode {
        case .grid:
            newVC = GridGalleryViewController(settings: settings, viewModel: viewModel)
        default:
            newVC = SlideshowViewController(settings: settings, viewModel: viewModel)
        }
        let old = currentDisplayVC
        currentDisplayVC = newVC
        addChild(newVC)
        newVC.view.frame = view.bounds
        newVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(newVC.view, belowSubview: clockView)
        newVC.didMove(toParent: self)
        if let old = old {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
    }

    @objc private func onDisplayModeChanged() { showDisplayVC(animated: true) }
    @objc private func onSlideshowSettingsChanged() {
        clockView.isHidden = !settings.showClock
        if settings.showClock { clockView.startClock() } else { clockView.stopClock() }
    }

    // MARK: - FrameViewModelDelegate
    func viewModelDidReloadPhotos(_ vm: FrameViewModel) { showDisplayVC() }
    func viewModelDidFailLoading(_ vm: FrameViewModel, error: Error) { showDisplayVC() }
    func viewModelDidAdvance(_ vm: FrameViewModel) {}
}
