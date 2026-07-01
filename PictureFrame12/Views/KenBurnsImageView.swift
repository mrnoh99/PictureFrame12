import UIKit

/// UIImageView subclass that animates Ken Burns (pan + zoom) effect.
final class KenBurnsImageView: UIView {
    private let imageView = UIImageView()
    private let blurBG = UIImageView()
    private var currentAnimation: UIViewPropertyAnimator?

    var image: UIImage? {
        didSet { updateImage() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        blurBG.contentMode = .scaleAspectFill
        blurBG.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurBG)
        NSLayoutConstraint.activate([
            blurBG.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurBG.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurBG.topAnchor.constraint(equalTo: topAnchor),
            blurBG.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        let blurOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurOverlay)
        NSLayoutConstraint.activate([
            blurOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurOverlay.topAnchor.constraint(equalTo: topAnchor),
            blurOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateImage() {
        imageView.image = image
        blurBG.image = image
    }

    func startKenBurns(duration: TimeInterval, intensity: Double) {
        stopKenBurns()
        guard duration > 0 else { return }

        let scale: CGFloat = 1.0 + CGFloat(intensity) * 0.15
        let dx = bounds.width  * CGFloat(intensity) * 0.05
        let dy = bounds.height * CGFloat(intensity) * 0.05

        let directions: [CGPoint] = [CGPoint(x: dx, y: dy), CGPoint(x: -dx, y: dy),
                                     CGPoint(x: dx, y: -dy), CGPoint(x: -dx, y: -dy)]
        let dir = directions.randomElement() ?? .zero

        imageView.transform = .identity
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) { [weak self] in
            self?.imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: dir.x, y: dir.y)
        }
        animator.startAnimation()
        currentAnimation = animator
    }

    func stopKenBurns() {
        currentAnimation?.stopAnimation(true)
        currentAnimation = nil
        imageView.transform = .identity
    }
}
