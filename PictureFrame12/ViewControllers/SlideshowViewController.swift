import UIKit

/// Slideshow with Ken Burns and UIKit transitions. Replaces SwiftUI SlideshowView.
final class SlideshowViewController: UIViewController, FrameViewModelDelegate {
    private let settings: SettingsStore
    private let viewModel: FrameViewModel
    private var currentPhotoView: KenBurnsImageView?
    private var isTransitioning = false
    private let loadingIndicator = UIActivityIndicatorView(style: .whiteLarge)
    private var sceneIndex = 0

    init(settings: SettingsStore, viewModel: FrameViewModel) {
        self.settings = settings
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupGestures()
        setupLoadingIndicator()
        viewModel.delegate = self
        if !viewModel.photos.isEmpty { showCurrentPhoto() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.stopSlideTimer()
        currentPhotoView?.stopKenBurns()
    }

    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
    }

    private func setupLoadingIndicator() {
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func handleSwipeLeft() { viewModel.advance() }
    @objc private func handleSwipeRight() { viewModel.previous() }

    private func startTimer() {
        let count = settings.collagePhotoCount(forScene: viewModel.currentIndex)
        if count <= 1 { viewModel.startSlideTimer(step: 1) }
        else { viewModel.startCollageTimer() }
    }

    private func showCurrentPhoto() {
        guard !viewModel.photos.isEmpty else { return }
        let count = settings.isSinglePhotoShow ? 1 : settings.collagePhotoCount(forScene: viewModel.currentIndex)
        if count > 1 {
            showCollage(count: count)
        } else {
            let photo = viewModel.photos[viewModel.currentIndex]
            let newView = KenBurnsImageView(frame: view.bounds)
            newView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            loadingIndicator.startAnimating()
            viewModel.loadImage(for: photo, targetSize: view.bounds.size) { [weak self] image in
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                newView.image = image
                self.transitionToView(newView)
                if self.settings.kenBurnsEnabled {
                    newView.startKenBurns(duration: self.settings.slideInterval, intensity: self.settings.kenBurnsIntensity)
                }
            }
        }
    }

    private func showCollage(count: Int) {
        let collageVC = CollageViewController(settings: settings, viewModel: viewModel, photoCount: count)
        let newView = collageVC.view!
        newView.frame = view.bounds
        newView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(collageVC)
        transitionToView(newView)
        collageVC.didMove(toParent: self)
    }

    private func transitionToView(_ newView: UIView) {
        guard !isTransitioning else { return }
        let transition = settings.slideTransition.resolved(
            pool: settings.selectedTransitions, index: sceneIndex)
        sceneIndex += 1

        if let old = currentPhotoView {
            isTransitioning = true
            transition.apply(from: old, to: newView, in: view, duration: 1.0) { [weak self] in
                self?.isTransitioning = false
                if let kb = self?.currentPhotoView { kb.stopKenBurns() }
                self?.currentPhotoView = newView as? KenBurnsImageView
            }
        } else {
            view.addSubview(newView)
            currentPhotoView = newView as? KenBurnsImageView
        }
        viewModel.prefetchUpcoming(targetSize: view.bounds.size)
    }

    // MARK: - FrameViewModelDelegate
    func viewModelDidReloadPhotos(_ vm: FrameViewModel) {
        sceneIndex = 0
        showCurrentPhoto()
        startTimer()
    }
    func viewModelDidFailLoading(_ vm: FrameViewModel, error: Error) {}
    func viewModelDidAdvance(_ vm: FrameViewModel) {
        guard !isTransitioning else { return }
        showCurrentPhoto()
    }
}
