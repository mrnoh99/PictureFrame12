import UIKit
import Photos

final class SettingsViewController: UITableViewController {
    private let settings: SettingsStore
    private let audioPlayer: AudioPlayerService
    private let lightroomAuth: LightroomAuthService

    private enum Section: Int, CaseIterable {
        case albums = 0
        case display
        case slideshow
        case music
        case overlay
    }

    init(settings: SettingsStore, audioPlayer: AudioPlayerService, lightroomAuth: LightroomAuthService) {
        self.settings = settings
        self.audioPlayer = audioPlayer
        self.lightroomAuth = lightroomAuth
        super.init(style: .grouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "설정"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
            target: self, action: #selector(done))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SwitchCell.self,  forCellReuseIdentifier: "switch")
        tableView.register(StepperCell.self, forCellReuseIdentifier: "stepper")
        tableView.register(SliderCell.self,  forCellReuseIdentifier: "slider")
    }

    @objc private func done() { dismiss(animated: true) }

    // MARK: - Table

    override func numberOfSections(in tv: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .albums:    return settings.selectedAlbums.count + 3
        case .display:   return 1
        case .slideshow: return 5
        case .music:     return settings.musicEnabled ? 4 : 1
        case .overlay:   return 3  // clock, weather, always-show-controls
        }
    }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .albums:    return "사진 소스"
        case .display:   return "표시 모드"
        case .slideshow: return "슬라이드쇼"
        case .music:     return "배경음악"
        case .overlay:   return "오버레이"
        }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .albums:    return albumCell(tv, at: indexPath)
        case .display:
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = settings.displayMode.displayName
            cell.accessoryType = .disclosureIndicator
            return cell
        case .slideshow: return slideshowCell(tv, at: indexPath)
        case .music:     return musicCell(tv, at: indexPath)
        case .overlay:   return overlayCell(tv, at: indexPath)
        }
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .albums:    handleAlbumTap(at: indexPath)
        case .display:   showDisplayModePicker()
        case .slideshow: handleSlideshowTap(at: indexPath)
        case .music:     handleMusicTap(at: indexPath)
        case .overlay:   break
        }
    }

    override func tableView(_ tv: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard Section(rawValue: indexPath.section) == .albums else { return false }
        return indexPath.row < settings.selectedAlbums.count
    }

    override func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                             forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, Section(rawValue: indexPath.section) == .albums,
           indexPath.row < settings.selectedAlbums.count {
            settings.removeAlbum(settings.selectedAlbums[indexPath.row])
            tv.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Cell Builders

    private func albumCell(_ tv: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let addOffset = settings.selectedAlbums.count
        if indexPath.row < addOffset {
            cell.textLabel?.text = settings.selectedAlbums[indexPath.row].title
            cell.accessoryType = .none
        } else {
            let actions = ["+  iOS 사진에서 선택", "+ Lightroom에서 선택", "+ 폴더에서 선택"]
            cell.textLabel?.text = actions[indexPath.row - addOffset]
            cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
            cell.accessoryType = .none
        }
        return cell
    }

    private func slideshowCell(_ tv: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tv.dequeueReusableCell(withIdentifier: "stepper", for: indexPath) as! StepperCell
            cell.configure(title: "전환 간격(s)", value: settings.slideInterval, min: 2, max: 60, step: 1) { [weak self] v in
                self?.settings.slideInterval = v
            }
            return cell
        case 1:
            let cell = tv.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            cell.configure(title: "Ken Burns 효과", isOn: settings.kenBurnsEnabled) { [weak self] v in
                self?.settings.kenBurnsEnabled = v
            }
            return cell
        case 2:
            let cell = tv.dequeueReusableCell(withIdentifier: "slider", for: indexPath) as! SliderCell
            cell.configure(title: "Ken Burns 강도", value: Float(settings.kenBurnsIntensity), min: 0, max: 1) { [weak self] v in
                self?.settings.kenBurnsIntensity = Double(v)
            }
            return cell
        case 3:
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "전환 효과: \(settings.slideTransition.displayName)"
            cell.accessoryType = .disclosureIndicator
            return cell
        case 4:
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "선택 채우기: \(settings.slideshowFitStyle.displayName)"
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        }
    }

    private func musicCell(_ tv: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tv.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            cell.configure(title: "배경음악 사용", isOn: settings.musicEnabled) { [weak self] v in
                self?.settings.musicEnabled = v
                self?.tableView.reloadSections(IndexSet(integer: Section.music.rawValue), with: .automatic)
            }
            return cell
        case 1:
            let cell = tv.dequeueReusableCell(withIdentifier: "slider", for: indexPath) as! SliderCell
            cell.configure(title: "볼륨", value: Float(settings.musicVolume), min: 0, max: 1) { [weak self] v in
                self?.settings.musicVolume = Double(v)
                self?.audioPlayer.setVolume(Double(v))
            }
            return cell
        case 2:
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "+ 음악 파일 추가"
            cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
            return cell
        case 3:
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "음악 폴더: \(settings.musicFolderName ?? "없음")"
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        }
    }

    private func overlayCell(_ tv: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tv.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            cell.configure(title: "시계 표시", isOn: settings.showClock) { [weak self] v in
                self?.settings.showClock = v
            }
            return cell
        case 1:
            let cell = tv.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            cell.configure(title: "날씨 표시", isOn: settings.showWeather) { [weak self] v in
                self?.settings.showWeather = v
            }
            return cell
        case 2:
            let cell = tv.dequeueReusableCell(withIdentifier: "switch", for: indexPath) as! SwitchCell
            cell.configure(title: "설정 버튼 항상 표시", isOn: settings.alwaysShowControls) { [weak self] v in
                self?.settings.alwaysShowControls = v
            }
            return cell
        default:
            return tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        }
    }

    // MARK: - Actions

    private func handleAlbumTap(at indexPath: IndexPath) {
        let addOffset = settings.selectedAlbums.count
        guard indexPath.row >= addOffset else { return }
        switch indexPath.row - addOffset {
        case 0: showAlbumPicker(source: .photoLibrary)
        case 1: showAlbumPicker(source: .lightroom)
        case 2: showFolderPicker()
        default: break
        }
    }

    private func showAlbumPicker(source: PhotoSourceKind) {
        let photoLib = PhotoLibraryService()
        let lrSvc = LightroomService(auth: lightroomAuth)
        let vc = AlbumPickerViewController(source: source, settings: settings,
                                           photoLib: photoLib, lightroomSvc: lrSvc)
        vc.delegate = self
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func showFolderPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func showDisplayModePicker() {
        let sheet = UIAlertController(title: "표시 모드", message: nil, preferredStyle: .actionSheet)
        for mode in DisplayMode.selectableCases {
            sheet.addAction(UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.settings.displayMode = mode
                self?.tableView.reloadSections(IndexSet(integer: Section.display.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = tableView }
        present(sheet, animated: true)
    }

    private func handleSlideshowTap(at indexPath: IndexPath) {
        if indexPath.row == 3 { showTransitionPicker() }
        else if indexPath.row == 4 { showFitStylePicker() }
    }

    private func showTransitionPicker() {
        let sheet = UIAlertController(title: "전환 효과", message: nil, preferredStyle: .actionSheet)
        for t in SlideTransition.allCases {
            sheet.addAction(UIAlertAction(title: t.displayName, style: .default) { [weak self] _ in
                self?.settings.slideTransition = t
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = tableView }
        present(sheet, animated: true)
    }

    private func showFitStylePicker() {
        let sheet = UIAlertController(title: "선택 채우기", message: nil, preferredStyle: .actionSheet)
        for style in CollageFitStyle.allCases {
            sheet.addAction(UIAlertAction(title: style.displayName, style: .default) { [weak self] _ in
                self?.settings.slideshowFitStyle = style
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = tableView }
        present(sheet, animated: true)
    }

    private func handleMusicTap(at indexPath: IndexPath) {
        if indexPath.row == 2 { showMusicFilePicker() }
        else if indexPath.row == 3 { showMusicFolderPicker() }
    }

    private func showMusicFilePicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    private func showMusicFolderPicker() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
}

// MARK: - AlbumPickerDelegate
extension SettingsViewController: AlbumPickerDelegate {
    func albumPicker(_ vc: AlbumPickerViewController, didSelect album: Album) {
        let sel = AlbumSelection(source: album.source, albumID: album.id, title: album.title)
        settings.addAlbum(sel)
        tableView.reloadSections(IndexSet(integer: Section.albums.rawValue), with: .automatic)
    }
}

// MARK: - UIDocumentPickerDelegate
extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            if url.hasDirectoryPath {
                try? settings.addFolderAlbum(url: url)
            } else {
                let fm = FileManager.default
                let dest = SettingsStore.musicDirectory.appendingPathComponent(url.lastPathComponent)
                try? fm.copyItem(at: url, to: dest)
                if !settings.musicTracks.contains(url.lastPathComponent) {
                    settings.musicTracks.append(url.lastPathComponent)
                }
            }
        }
        tableView.reloadData()
    }
}

// MARK: - Reusable Cells

final class SwitchCell: UITableViewCell {
    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryView = toggle
        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        textLabel?.text = title
        toggle.isOn = isOn
        self.onChange = onChange
    }
    @objc private func switched() { onChange?(toggle.isOn) }
}

final class StepperCell: UITableViewCell {
    private let stepper = UIStepper()
    private let valueLabel = UILabel()
    private var onChange: ((Double) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        valueLabel.textColor = .gray
        let stack = UIStackView(arrangedSubviews: [valueLabel, stepper])
        stack.spacing = 8
        accessoryView = stack
        stepper.addTarget(self, action: #selector(stepped), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: Double, min: Double, max: Double, step: Double,
                   onChange: @escaping (Double) -> Void) {
        textLabel?.text = title
        stepper.minimumValue = min; stepper.maximumValue = max; stepper.stepValue = step
        stepper.value = value
        valueLabel.text = String(format: "%.0f", value)
        self.onChange = onChange
    }
    @objc private func stepped() {
        valueLabel.text = String(format: "%.0f", stepper.value)
        onChange?(stepper.value)
    }
}

final class SliderCell: UITableViewCell {
    private let slider = UISlider()
    private var onChange: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        slider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 120),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        slider.addTarget(self, action: #selector(slid), for: .valueChanged)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: Float, min: Float, max: Float, onChange: @escaping (Float) -> Void) {
        textLabel?.text = title
        slider.minimumValue = min; slider.maximumValue = max; slider.value = value
        self.onChange = onChange
    }
    @objc private func slid() { onChange?(slider.value) }
}
