import UIKit

final class WelcomeViewController: UIViewController {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGradientBackground()
        setupContent()
    }

    private func setupGradientBackground() {
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1).cgColor,
                           UIColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func setupContent() {
        let iconLabel = UILabel()
        iconLabel.text = "\u{1F5BC}"
        iconLabel.font = UIFont.systemFont(ofSize: 64)
        iconLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = "Picture Frame"
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .thin)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "설정에서 사진을 선택해주세요"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .light)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [iconLabel, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
