import UIKit

final class GridGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let settings: SettingsStore
    private let viewModel: FrameViewModel
    private var collectionView: UICollectionView!
    private let cellID = "PhotoCell"

    init(settings: SettingsStore, viewModel: FrameViewModel) {
        self.settings = settings
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellID)
        view.addSubview(collectionView)
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.photos.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath)
        cell.backgroundColor = UIColor(white: 0.1, alpha: 1)
        let iv: UIImageView
        if let existing = cell.contentView.viewWithTag(1) as? UIImageView {
            iv = existing
        } else {
            iv = UIImageView(frame: cell.contentView.bounds)
            iv.tag = 1
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cell.contentView.addSubview(iv)
        }
        iv.image = nil
        let photo = viewModel.photos[indexPath.item]
        viewModel.loadImage(for: photo, targetSize: cell.bounds.size) { image in
            if cv.indexPath(for: cell) == indexPath { iv.image = image }
        }
        return cell
    }

    func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cols: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 5 : 3
        let w = (cv.bounds.width - (cols - 1) * 2) / cols
        return CGSize(width: w, height: w)
    }
}
