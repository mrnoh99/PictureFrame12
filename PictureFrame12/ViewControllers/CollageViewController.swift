import UIKit

/// Lays out multiple photos using CollageLayouts templates.
final class CollageViewController: UIViewController {
    private let settings: SettingsStore
    private let viewModel: FrameViewModel
    private let photoCount: Int
    private var imageViews: [UIImageView] = []

    init(settings: SettingsStore, viewModel: FrameViewModel, photoCount: Int) {
        self.settings = settings
        self.viewModel = viewModel
        self.photoCount = photoCount
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if imageViews.isEmpty { layoutPhotos() }
    }

    private func layoutPhotos() {
        let photos = viewModel.collageBatch(count: photoCount)
        let template = CollageLayouts.template(count: photos.count, variant: viewModel.currentIndex)
        let bounds = view.bounds

        for (i, photo) in photos.enumerated() {
            let cell = template.cells[i]
            let frame = CGRect(
                x: cell.minX * bounds.width,
                y: cell.minY * bounds.height,
                width: cell.width * bounds.width,
                height: cell.height * bounds.height)
            let iv = UIImageView(frame: frame)
            iv.contentMode = settings.slideshowFitStyle == .blurFill ? .scaleAspectFit : .scaleAspectFill
            iv.clipsToBounds = true
            view.addSubview(iv)
            imageViews.append(iv)

            viewModel.loadImage(for: photo, targetSize: frame.size) { image in
                iv.image = image
            }
        }
    }
}
