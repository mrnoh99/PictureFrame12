import UIKit
import Photos

protocol AlbumPickerDelegate: AnyObject {
    func albumPicker(_ vc: AlbumPickerViewController, didSelect album: Album)
}

final class AlbumPickerViewController: UITableViewController {
    private let source: PhotoSourceKind
    private let settings: SettingsStore
    private let photoLib: PhotoLibraryService
    private let lightroomSvc: LightroomService
    weak var delegate: AlbumPickerDelegate?

    private var albums: [Album] = []
    private let spinner = UIActivityIndicatorView(style: .gray)

    init(source: PhotoSourceKind, settings: SettingsStore,
         photoLib: PhotoLibraryService, lightroomSvc: LightroomService) {
        self.source = source
        self.settings = settings
        self.photoLib = photoLib
        self.lightroomSvc = lightroomSvc
        super.init(style: .grouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = source.displayName
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
            target: self, action: #selector(dismiss_))
        spinner.hidesWhenStopped = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        fetchAlbums()
    }

    @objc private func dismiss_() { dismiss(animated: true) }

    private func fetchAlbums() {
        spinner.startAnimating()
        let provider: PhotoProvider = source == .lightroom ? lightroomSvc : photoLib
        provider.fetchAlbums { [weak self] result in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            switch result {
            case .success(let a):
                self.albums = a
                self.tableView.reloadData()
            case .failure(let e):
                let alert = UIAlertController(title: "오류", message: e.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { albums.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let album = albums[indexPath.row]
        cell.textLabel?.text = album.title
        let selected = settings.selectedAlbums.contains { $0.albumID == album.id }
        cell.accessoryType = selected ? .checkmark : .none
        if let count = album.estimatedCount {
            cell.detailTextLabel?.text = "\(count)"
        }
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        delegate?.albumPicker(self, didSelect: albums[indexPath.row])
        dismiss(animated: true)
    }
}
