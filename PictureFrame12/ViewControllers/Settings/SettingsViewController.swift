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

    // Which button triggered the currently-presented UIDocumentPickerViewController.
    // The delegate is shared across all pickers, so it needs this to know how to
    // interpret the returned URLs (photo folder vs. music file vs. music folder).
    private enum PickerContext {
        case photoFolder
        case musicFile
        case musicFolder
    }
    private var pickerContext: PickerContext?

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

    override func numberOfSections(in tv: UITableView) -> Int { return Section.allCases.count }

    // Music section rows when enabled: 0 toggle, 1 volume, 2 "+file", 3
    // "+folder", then one row per imported track (musicRowsCount - 4 of them).
    private var musicTrackRows: [String] {
        return settings.musicTracks + settings.musicFolderTracks
    }
    private var musicRowsCount: Int {
        return settings.musicEnabled ? 4 + musicTrackRows.count : 1
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .albums:    return settings.selectedAlbums.count + 3
        case .display:   return 1
        case .slideshow: return 7
        case .music:     return musicRowsCount
        case .overlay:   return 3
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
        let sourceCell = tv.cellForRow(at: indexPath)
        switch Section(rawValue: indexPath.section)! {
        case .albums:    handleAlbumTap(at: indexPath)
        case .display:   showDisplayModePicker(from: sourceCell)
        case .slideshow: handleSlideshowTap(at: indexPath, from: sourceCell)
        case .music:     handleMusicTap(at: indexPath)
        case .overlay:   break
        }
    }

    override func tableView(_ tv: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if Section(rawValue: indexPath.section) == .albums {
            return indexPath.row < settings.selectedAlbums.count
        }
        if Section(rawValue: indexPath.section) == .music {
            return indexPath.row >= 4 && indexPath.row < musicRowsCount
        }
        return false
    }

    override func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                             forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        switch Section(rawValue: indexPath.section)! {
        case .albums where indexPath.row < settings.selectedAlbums.count:
            settings.removeAlbum(settings.selectedAlbums[indexPath.row])
            tv.deleteRows(at: [indexPath], with: .automatic)
        case .music where indexPath.row >= 4:
            removeMusicTrack(at: indexPath.row - 4)
            tv.deleteRows(at: [indexPath], with: .automatic)
        default: break
        }
    }

    private func removeMusicTrack(at trackIndex: Int) {
        if trackIndex < settings.musicTracks.count {
            let name = settings.musicTracks.remove(at: trackIndex)
            try? FileManager.default.removeItem(at: SettingsStore.musicDirectory.appendingPathComponent(name))
        } else {
            let folderIndex = trackIndex - settings.musicTracks.count
            guard folderIndex < settings.musicFolderTracks.count else { return }
            let name = settings.musicFolderTracks.remove(at: folderIndex)
            try? FileManager.default.removeItem(at: SettingsStore.musicDirectory.appendingPathComponent(name))
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
        case 5:
            let cell = tv.dequeueReusableCell(withIdentifier: "stepper", for: indexPath) as! StepperCell
            let maxVal = Double(max(settings.collageRangeMin, settings.collageRangeMax))
            cell.configure(title: "최소 사진 수", value: Double(settings.collageRangeMin),
                           min: 1, max: maxVal, step: 1) { [weak self] v in
                self?.settings.collageRangeMin = Int(v)
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .none)
            }
            return cell
        case 6:
            let cell = tv.dequeueReusableCell(withIdentifier: "stepper", for: indexPath) as! StepperCell
            let minVal = Double(min(settings.collageRangeMin, settings.collageRangeMax))
            cell.configure(title: "최대 사진 수", value: Double(settings.collageRangeMax),
                           min: minVal, max: 9, step: 1) { [weak self] v in
                self?.settings.collageRangeMax = Int(v)
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .none)
            }
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
            let name = settings.musicFolderName.map { " (\($0))" } ?? ""
            cell.textLabel?.text = "+ 음악 폴더에서 가져오기\(name)"
            cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
            return cell
        default:
            // One row per imported track (musicTracks then musicFolderTracks),
            // so the user can see and swipe-to-delete what was actually added —
            // this is what was missing before: picking succeeded but nothing
            // ever showed up in the list.
            let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            let trackIndex = indexPath.row - 4
            let name = trackIndex < musicTrackRows.count ? musicTrackRows[trackIndex] : ""
            cell.textLabel?.text = "🎵 \((name as NSString).deletingPathExtension)"
            cell.textLabel?.textColor = .black
            return cell
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

    // NOTE: an earlier version of this used UIDocumentPickerViewController(
    // documentTypes: ["public.folder"], in: .open) so the user could pick a
    // live folder. On-device testing (iPad mini 3, iOS 12.5.8) showed that
    // mode reaches a dead end for iCloud-hosted folders: browsing into a
    // folder with no subfolders never shows an Open/Done button at all — only
    // Cancel. So we use the same reliable checkbox multi-select flow as the
    // other pickers (.import mode) instead: it lets the user check either
    // individual photos OR whole folders, and reliably surfaces an enabled
    // "완료" button. See documentPicker(_:didPickDocumentsAt:) for how folder
    // vs. file results are told apart.
    private func showFolderPicker() {
        pickerContext = .photoFolder
        let picker = UIDocumentPickerViewController(
            documentTypes: ["public.folder", "public.image", "public.jpeg", "public.png",
                            "public.tiff", "com.apple.photo"],
            in: .import)
        picker.delegate = self
        if #available(iOS 11, *) { picker.allowsMultipleSelection = true }
        present(picker, animated: true)
    }

    private func showDisplayModePicker(from sourceCell: UITableViewCell?) {
        let sheet = UIAlertController(title: "표시 모드", message: nil, preferredStyle: .actionSheet)
        for mode in DisplayMode.selectableCases {
            sheet.addAction(UIAlertAction(title: mode.displayName, style: .default) { [weak self] _ in
                self?.settings.displayMode = mode
                self?.tableView.reloadSections(IndexSet(integer: Section.display.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sourceCell ?? tableView
            pop.sourceRect = sourceCell?.bounds ?? CGRect(x: tableView.bounds.midX, y: 0, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func handleSlideshowTap(at indexPath: IndexPath, from sourceCell: UITableViewCell?) {
        if indexPath.row == 3 { showTransitionPicker(from: sourceCell) }
        else if indexPath.row == 4 { showFitStylePicker(from: sourceCell) }
    }

    private func showTransitionPicker(from sourceCell: UITableViewCell?) {
        let sheet = UIAlertController(title: "전환 효과", message: nil, preferredStyle: .actionSheet)
        for t in SlideTransition.allCases {
            sheet.addAction(UIAlertAction(title: t.displayName, style: .default) { [weak self] _ in
                self?.settings.slideTransition = t
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sourceCell ?? tableView
            pop.sourceRect = sourceCell?.bounds ?? CGRect(x: tableView.bounds.midX, y: 0, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func showFitStylePicker(from sourceCell: UITableViewCell?) {
        let sheet = UIAlertController(title: "선택 채우기", message: nil, preferredStyle: .actionSheet)
        for style in CollageFitStyle.allCases {
            sheet.addAction(UIAlertAction(title: style.displayName, style: .default) { [weak self] _ in
                self?.settings.slideshowFitStyle = style
                self?.tableView.reloadSections(IndexSet(integer: Section.slideshow.rawValue), with: .automatic)
            })
        }
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sourceCell ?? tableView
            pop.sourceRect = sourceCell?.bounds ?? CGRect(x: tableView.bounds.midX, y: 0, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func handleMusicTap(at indexPath: IndexPath) {
        if indexPath.row == 2 { showMusicFilePicker() }
        else if indexPath.row == 3 { showMusicFolderPicker() }
    }

    private func showMusicFilePicker() {
        pickerContext = .musicFile
        let picker = UIDocumentPickerViewController(
            documentTypes: ["public.audio", "public.mp3", "com.apple.m4a-audio",
                            "public.aiff-audio", "public.aifc-audio"],
            in: .import)
        picker.delegate = self
        if #available(iOS 11, *) { picker.allowsMultipleSelection = true }
        present(picker, animated: true)
    }

    // Lets the user check a whole folder of music (instead of individual
    // files). "public.folder" MUST be included in documentTypes here — without
    // it, iOS lets the checkbox UI show folders as selectable but silently
    // refuses to complete when one is checked (the 완료 button looks enabled
    // but tapping it does nothing, which is what made this look "stuck").
    private func showMusicFolderPicker() {
        pickerContext = .musicFolder
        let picker = UIDocumentPickerViewController(
            documentTypes: ["public.folder", "public.audio", "public.mp3", "com.apple.m4a-audio",
                            "public.aiff-audio", "public.aifc-audio"],
            in: .import)
        picker.delegate = self
        if #available(iOS 11, *) { picker.allowsMultipleSelection = true }
        present(picker, animated: true)
    }

    private func showFolderAddError(_ error: Error) {
        let alert = UIAlertController(title: "폴더를 추가할 수 없습니다",
                                       message: error.localizedDescription,
                                       preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aifc", "caf"]
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"]

    // Recursively collects files with one of the given extensions from a
    // security-scoped folder URL (used when the user checks a whole folder
    // instead of individual files).
    private func collectFiles(in folder: URL, matching extensions: Set<String>) -> [URL] {
        let needsScope = folder.startAccessingSecurityScopedResource()
        defer { if needsScope { folder.stopAccessingSecurityScopedResource() } }
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }
        var results: [URL] = []
        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDir, extensions.contains(url.pathExtension.lowercased()) {
                results.append(url)
            }
        }
        return results
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
        let context = pickerContext
        pickerContext = nil
        // iOS 12 sometimes fails to auto-dismiss the Files sheet after a pick,
        // which looks to the user like "selection does nothing" (only Cancel
        // closes it). Dismiss explicitly (from the presenter, not the picker
        // itself) so the sheet always closes here.
        dismiss(animated: true)

        var isDir: ObjCBool = false
        let directories = urls.filter {
            FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue
        }
        let files = urls.filter { !directories.contains($0) }

        switch context {
        case .photoFolder:
            // A checked folder becomes a live, bookmarked album (read on the
            // fly by FolderPhotoService). Checked individual photo files are
            // copied into the app sandbox, same as before.
            for folder in directories {
                do { try settings.addFolderAlbum(url: folder) }
                catch { showFolderAddError(error) }
            }
            let imageFiles = files.filter { SettingsViewController.imageExtensions.contains($0.pathExtension.lowercased()) }
            if !imageFiles.isEmpty { try? settings.addImportedPhotos(urls: imageFiles) }

        case .musicFile:
            importMusicFiles(files.filter { SettingsViewController.audioExtensions.contains($0.pathExtension.lowercased()) },
                              intoFolderList: false)

        case .musicFolder:
            var toImport = files.filter { SettingsViewController.audioExtensions.contains($0.pathExtension.lowercased()) }
            for folder in directories {
                toImport += collectFiles(in: folder, matching: SettingsViewController.audioExtensions)
            }
            if let firstFolder = directories.first {
                settings.musicFolderName = firstFolder.lastPathComponent
            }
            importMusicFiles(toImport, intoFolderList: true)

        case nil:
            break
        }

        tableView.reloadData()
    }

    // intoFolderList picks which SettingsStore list the copied track names are
    // recorded in, so the settings screen and musicURLs can tell "individually
    // added" tracks apart from "imported via a folder" tracks.
    private func importMusicFiles(_ urls: [URL], intoFolderList: Bool) {
        for url in urls {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            var destName = url.lastPathComponent
            var dest = SettingsStore.musicDirectory.appendingPathComponent(destName)
            if FileManager.default.fileExists(atPath: dest.path) {
                let base = (destName as NSString).deletingPathExtension
                let ext = (destName as NSString).pathExtension
                destName = "\(base)_\(String(UUID().uuidString.prefix(8))).\(ext)"
                dest = SettingsStore.musicDirectory.appendingPathComponent(destName)
            }
            try? FileManager.default.copyItem(at: url, to: dest)
            if intoFolderList {
                if !settings.musicFolderTracks.contains(destName) { settings.musicFolderTracks.append(destName) }
            } else {
                if !settings.musicTracks.contains(destName) { settings.musicTracks.append(destName) }
            }
        }
    }

    // Deprecated iOS 8 fallback — iOS 12 may call this instead of didPickDocumentsAt
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        documentPicker(controller, didPickDocumentsAt: [url])
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickerContext = nil
        dismiss(animated: true)
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
        valueLabel.textAlignment = .right
        valueLabel.frame = CGRect(x: 0, y: 0, width: 36, height: 44)
        stepper.frame = CGRect(x: 44, y: 4, width: 94, height: 36)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 144, height: 44))
        container.addSubview(valueLabel)
        container.addSubview(stepper)
        accessoryView = container
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
        // Slider pinned to right side, width = 40% of cell (roughly half the original)
        NSLayoutConstraint.activate([
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.40),
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
