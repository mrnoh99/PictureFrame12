import UIKit

/// Floating clock + date overlay view (replaces SwiftUI TimelineView).
final class ClockOverlayView: UIView {
    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .thin)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        timeLabel.layer.shadowColor = UIColor.black.cgColor
        timeLabel.layer.shadowOpacity = 0.6
        timeLabel.layer.shadowRadius = 4
        timeLabel.layer.shadowOffset = CGSize(width: 1, height: 1)

        dateLabel.font = UIFont.systemFont(ofSize: 16, weight: .light)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        dateLabel.textAlignment = .center
        dateLabel.layer.shadowColor = UIColor.black.cgColor
        dateLabel.layer.shadowOpacity = 0.5
        dateLabel.layer.shadowRadius = 3
        dateLabel.layer.shadowOffset = CGSize(width: 1, height: 1)

        let stack = UIStackView(arrangedSubviews: [timeLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

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
}
