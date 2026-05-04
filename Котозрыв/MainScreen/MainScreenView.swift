import UIKit

protocol MainScreenViewProtocol: AnyObject {
    var presenter: MainScreenPresenterProtocol? { get set }
}

final class MainScreenView: UIViewController {

    var presenter: MainScreenPresenterProtocol?

    private let logoImageView = Theme.makeLogoImageView()
    private let sloganLabel   = Theme.makeAccentLabel("КАРТОЧНАЯ ИГРА · СОЛО И ОНЛАЙН", size: 11, kerning: 4)

    private let singlePlayerButton = MainScreenView.makeMenuButton(
        title: "ОДИНОЧНАЯ ИГРА", subtitle: "ПРОТИВ ИИ", filled: true)
    private let multiplayerButton  = MainScreenView.makeMenuButton(
        title: "ОНЛАЙН-ИГРА", subtitle: "С ДРУЗЬЯМИ ПО КОДУ", filled: true)
    private let settingsButton     = MainScreenView.makeMenuButton(
        title: "НАСТРОЙКИ", subtitle: nil, filled: false)

    private let decorExplodeCard = MainScreenView.makeDecorCard(imageName: "explode", angle: 15,  size: CGSize(width: 80, height: 104))
    private let decorDefuseCard  = MainScreenView.makeDecorCard(imageName: "defuse",  angle: -18, size: CGSize(width: 80, height: 104))

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(decorExplodeCard)
        view.addSubview(decorDefuseCard)

        view.addSubview(logoImageView)
        view.addSubview(sloganLabel)

        let buttonStack = UIStackView(arrangedSubviews: [singlePlayerButton, multiplayerButton, settingsButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 16
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.82),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),

            sloganLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
            sloganLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            sloganLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            buttonStack.topAnchor.constraint(equalTo: sloganLabel.bottomAnchor, constant: 50),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            singlePlayerButton.widthAnchor.constraint(equalToConstant: 244),
            multiplayerButton.widthAnchor.constraint(equalToConstant: 244),
            settingsButton.widthAnchor.constraint(equalToConstant: 244),

            decorExplodeCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            decorExplodeCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            decorDefuseCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            decorDefuseCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14)
        ])
    }

    private func bindActions() {
        singlePlayerButton.addTarget(self, action: #selector(singleTapped),   for: .touchUpInside)
        multiplayerButton.addTarget(self,  action: #selector(multiTapped),    for: .touchUpInside)
        settingsButton.addTarget(self,     action: #selector(settingsTapped), for: .touchUpInside)
    }

    @objc private func singleTapped()   { presenter?.singlePlayerButtonTapped() }
    @objc private func multiTapped()    { presenter?.multiplayerButtonTapped() }
    @objc private func settingsTapped() { presenter?.settingsButtonTapped() }

    // MARK: - Helpers

    private static func makeMenuButton(title: String, subtitle: String?, filled: Bool) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: filled ? 62 : 54).isActive = true
        button.layer.cornerRadius = (filled ? 62 : 54) / 2

        if filled {
            button.backgroundColor = Theme.Palette.yellow
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.25
            button.layer.shadowRadius = 8
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
        } else {
            button.backgroundColor = .clear
            button.layer.borderColor = Theme.Palette.yellow.cgColor
            button.layer.borderWidth = 2
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.notable(14)
        titleLabel.textColor = filled ? Theme.Palette.black : Theme.Palette.yellow
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)

        if let subtitle = subtitle {
            let subLabel = UILabel()
            subLabel.text = subtitle
            subLabel.font = Theme.notable(9)
            subLabel.textColor = filled ? Theme.Palette.black.withAlphaComponent(0.65) : Theme.Palette.yellow.withAlphaComponent(0.65)
            subLabel.textAlignment = .center
            subLabel.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(subLabel)
        }

        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        return button
    }

    private static func makeDecorCard(imageName: String, angle: CGFloat, size: CGSize) -> UIImageView {
        let iv = UIImageView(image: UIImage(named: imageName))
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOpacity = 0.45
        iv.layer.shadowRadius = 6
        iv.layer.shadowOffset = CGSize(width: 0, height: 4)
        iv.transform = CGAffineTransform(rotationAngle: angle * .pi / 180)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.widthAnchor.constraint(equalToConstant: size.width).isActive = true
        iv.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        return iv
    }
}

extension MainScreenView: MainScreenViewProtocol {}
