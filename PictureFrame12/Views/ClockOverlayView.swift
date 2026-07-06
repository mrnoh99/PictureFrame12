import UIKit

/// Floating clock + date + weather overlay pinned to the upper-left corner
/// behind a frosted glass pill (UIBlurEffect, available iOS 8+).
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
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 44, weight: .thin)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center

        dateLabel.font = UIFont.systemFont(ofSize: 13, weight: .light)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        dateLabel.textAlignment = .center

        weatherLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        weatherLabel.textColor = UIColor.white.withAlphaComponent(0.90)
        weatherLabel.textAlignment = .center
        weatherLabel.isHidden = true
    }

    private func setupLayout() {
        // Frosted glass pill container
        let pill = UIView()
        pill.layer.cornerRadius = 16
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false

        // Dark frosted blur (UIBlurEffect available since iOS 8)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.frame = pill.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pill.addSubview(blur)

        // Subtle dark tint over blur for extra contrast
        let tint = UIView()
        tint.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tint.frame = pill.bounds
        pill.addSubview(tint)

        // Vertical label stack
        let stack = UIStackView(arrangedSubviews: [timeLabel, dateLabel, weatherLabel])
        stack.axis      = .vertical
        stack.spacing   = 3
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
        ])

        addSubview(pill)

        // Pin pill to upper-left, respecting safe area on iOS 11+
        let topRef: NSLayoutYAxisAnchor
        if #available(iOS 11, *) {
            topRef = safeAreaLayoutGuide.topAnchor
        } else {
            topRef = topAnchor
        }
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: topRef, constant: 16),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
        ])
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
        weatherLabel.text     = "\(ClockOverlayView.emoji(for: info.symbolName))  \(info.temperatureString)"
        weatherLabel.isHidden = false
    }

    private static func emoji(for symbol: String) -> String {
        switch symbol {
        case "sun.max":             return "\u{2600}\u{FE0F}"  // ☀️
        case "cloud.sun":           return "\u{26C5}"           // ⛅
        case "cloud", "cloud.fill": return "\u{2601}\u{FE0F}"  // ☁️
        case "cloud.fog":           return "\u{1F32B}"          // 🌫
        case "cloud.drizzle":       return "\u{1F326}"          // 🌦
        case "cloud.sleet":         return "\u{1F328}"          // 🌨
        case "cloud.rain":          return "\u{1F327}"          // 🌧
        case "cloud.snow":          return "\u{2744}\u{FE0F}"   // ❄️
        case "cloud.heavyrain":     return "\u{26C8}"           // ⛈
        case "cloud.bolt":          return "\u{1F329}"          // 🌩
        case "cloud.bolt.rain":     return "\u{26C8}"           // ⛈
        default:                    return "\u{1F321}"          // 🌡
        }
    }
}
