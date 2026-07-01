import Foundation
import AVFoundation

final class AudioPlayerService: NSObject {
    private(set) var isPlaying = false
    private(set) var currentTrackName: String?

    private var player: AVAudioPlayer?
    private var tracks: [URL] = []
    private var index = 0
    private var volume: Float = 0.6

    func setTracks(_ urls: [URL]) {
        tracks = urls
        if index >= tracks.count { index = 0 }
    }

    func setVolume(_ value: Double) {
        volume = Float(max(0, min(1, value)))
        player?.volume = volume
    }

    func start() {
        guard !tracks.isEmpty, !isPlaying else { return }
        configureSession(active: true)
        if player == nil { startCurrent() } else { player?.play(); isPlaying = true }
    }

    func pause() { player?.pause(); isPlaying = false }

    func stop() { player?.stop(); player = nil; isPlaying = false; configureSession(active: false) }

    func next() {
        guard !tracks.isEmpty else { return }
        index = (index + 1) % tracks.count
        startCurrent()
    }

    private func startCurrent() {
        guard tracks.indices.contains(index) else { return }
        let url = tracks[index]
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.volume = volume
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
            currentTrackName = url.deletingPathExtension().lastPathComponent
        } catch {
            isPlaying = false; currentTrackName = nil
        }
    }

    private func configureSession(active: Bool) {
        let s = AVAudioSession.sharedInstance()
        if active { try? s.setCategory(.playback, mode: .default) }
        try? s.setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.next() }
    }
}
