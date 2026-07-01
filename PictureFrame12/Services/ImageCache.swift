import UIKit

/// 2-level cache (memory + disk). Uses CommonCrypto CC_SHA256 instead of CryptoKit (iOS 12 compatible).
final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "com.pictureframe12.imagecache.io", qos: .utility)
    private let directory: URL
    private let diskCapacity = 500 * 1024 * 1024

    private init() {
        memory.totalCostLimit = 200 * 1024 * 1024
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("PF12Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NotificationCenter.default.addObserver(
            self, selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        ioQueue.async { [weak self] in self?.trimDiskIfNeeded() }
    }

    private func cacheKey(id: String, size: CGSize) -> String {
        let w = Int(size.width / 50) * 50
        let h = Int(size.height / 50) * 50
        return "\(id)@\(w)x\(h)"
    }

    private func fileURL(for key: String) -> URL {
        let data = Data(key.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("jpg")
    }

    private func cost(of image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    func memoryImage(for id: String, size: CGSize) -> UIImage? {
        memory.object(forKey: cacheKey(id: id, size: size) as NSString)
    }

    func storeMemory(_ image: UIImage, for id: String, size: CGSize) {
        memory.setObject(image, forKey: cacheKey(id: id, size: size) as NSString, cost: cost(of: image))
    }

    func diskImage(for id: String, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let url = fileURL(for: cacheKey(id: id, size: size))
        ioQueue.async {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }; return
            }
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            DispatchQueue.main.async { completion(image) }
        }
    }

    func store(_ image: UIImage, for id: String, size: CGSize) {
        let k = cacheKey(id: id, size: size)
        memory.setObject(image, forKey: k as NSString, cost: cost(of: image))
        let url = fileURL(for: k)
        ioQueue.async {
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    @objc func clearMemory() { memory.removeAllObjects() }

    private func trimDiskIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize else { return nil }
            return (url, size, values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > diskCapacity else { return }
        for entry in entries.sorted(by: { $0.2 < $1.2 }) {
            if total <= diskCapacity { break }
            try? fm.removeItem(at: entry.0); total -= entry.1
        }
    }
}
