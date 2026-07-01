import UIKit

/// Floating clock + date + weather overlay (replaces SwiftUI TimelineView).
final class ClockOverlayView: UIView {
    private let timeLabel    = UILabel()
    private let dateLabel    = UILabel()
    private let weatherLabel = UILabel()
    private var timer: Timer?

    var showWeather: Bool = true {
        didSet { refreshWeather() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setupLabels()
        setupLayout()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshWeather),
            name: .weatherDidUpdate,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func setupLabels() {
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .thin)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        applyShadow(timeLabel, opacity: 0.6, radius: 4)

        dateLabel.font = UIFont.systemFont(ofSize: 16, weight: .light)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        dateLabel.textAlignment = .center
        applyShadow(dateLabel, opacity: 0.5, radius: 3)

        weatherLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        weatherLabel.textColor = UIColor.white.withAlphaComponent(0.90)
        weatherLabel.textAlignment = .center
        weatherLabel.isHidden = true
        applyShadow(weatherLabel, opacity: 0.5, radius: 3)
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [timeLabel, dateLabel, weatherLabel])
        stack.axis      = .vertical
        stack.spacing   = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    private func applyShadow(_ label: UILabel, opacity: Float, radius: CGFloat) {
        label.layer.shadowColor   = UIColor.black.cgColor
        label.layer.shadowOpacity = opacity
        label.layer.shadowRadius  = radius
        label.layer.shadowOffset  = CGSize(width: 1, height: 1)
    }

    // MARK: - Clock

    func startClock() {
        updateClock()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    func stopClock() { timer?.invalidate(); timer = nil }

    private func updateClock() {
        let now = Date()
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        timeLabel.text = tf.string(from: now)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        dateLabel.text = df.string(from: now)
    }

    // MARK: - Weather

    @objc private func refreshWeather() {
        guard showWeather, let info = WeatherManager.shared.currentWeather else {
            weatherLabel.isHidden = true
            return
        }
        weatherLabel.text     = "\(Self.emoji(for: info.symbolName))  \(info.temperatureString)"
        weatherLabel.isHidden = false
    }

    // Symbol key → emoji (works on all iOS versions)
    private static func emoji(for symbol: String) -> String {
        switch symbol {
        case "sun.max":          return "\u{2600}\u{FE0F}"  // ☀️
        case "cloud.sun":        return "\u{26C5}"           // ⛅
        case "cloud", "cloud.fill": return "\u{2601}\u{FE0F}" // ☁️
        case "cloud.fog":        return "\u{1F32B}"          // 🌫
        case "cloud.drizzle":    return "\u{1F326}"          // 🌦
        case "cloud.sleet":      return "\u{1F328}"          // 🌨
        case "cloud.rain":       return "\u{1F327}"          // 🌧
        case "cloud.snow":       return "\u{2744}\u{FE0F}"   // ❄️
        case "cloud.heavyrain":  return "\u{26C8}"           // ⛈
        case "cloud.bolt":       return "\u{1F329}"          // 🌩
        case "cloud.bolt.rain":  return "\u{26C8}"           // ⛈
        default:                 return "\u{1F321}"          // 🌡
        }
    }
}
