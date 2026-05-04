import UIKit

final class GameOverView: UIViewController {

    private let isWinner: Bool
    private let winnerName: String

    init(isWinner: Bool, winnerName: String) {
        self.isWinner = isWinner
        self.winnerName = winnerName
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)


        let glow = UIView()
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.isUserInteractionEnabled = false
        view.addSubview(glow)
        NSLayoutConstraint.activate([
            glow.topAnchor.constraint(equalTo: view.topAnchor),
            glow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            glow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        DispatchQueue.main.async { [weak self, weak glow] in
            guard let self = self, let glow = glow else { return }
            let layer = CAGradientLayer()
            layer.frame = glow.bounds
            layer.type  = .radial
            let centerColor: UIColor = self.isWinner
                ? Theme.Palette.yellow.withAlphaComponent(0.40)
                : Theme.Palette.red.withAlphaComponent(0.55)
            layer.colors = [centerColor.cgColor, UIColor.black.withAlphaComponent(0.85).cgColor]
            layer.locations = [0.0, 0.85]
            layer.startPoint = CGPoint(x: 0.5, y: 0.35)
            layer.endPoint   = CGPoint(x: 1.0, y: 1.0)
            glow.layer.addSublayer(layer)
        }

   
        let title = Theme.makeTitleLabel(isWinner ? "ПОБЕДА" : "ПРОВАЛ", size: 56)
        title.textColor = isWinner ? Theme.Palette.yellow : Theme.Palette.pink

        let subtitle = UILabel()
        let subText = isWinner ? "ВЫЖИЛ ТОЛЬКО ТЫ" : "ПОБЕДИЛ \(winnerName.uppercased())"
        subtitle.attributedText = NSAttributedString(
            string: subText,
            attributes: [.font: Theme.notable(13),
                         .foregroundColor: UIColor.white,
                         .kern: 2])
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let description = UILabel()
        description.font = Theme.mono(11)
        description.textColor = Theme.Palette.pink
        description.numberOfLines = 0
        description.textAlignment = .center
        description.text = isWinner
            ? "ВСЕ КОТЫ-ОППОНЕНТЫ ВЗОРВАЛИСЬ.\nТЫ ЧЕМПИОН КОТО-СОНАТЫ."
            : "КОТЁНОК БУМКНУЛ ПРЯМО У ТЕБЯ НА КОЛЕНЯХ.\nПОПРОБУЙ ЕЩЁ."
        description.translatesAutoresizingMaskIntoConstraints = false

        let topStack = UIStackView(arrangedSubviews: [title, subtitle, description])
        topStack.axis = .vertical
        topStack.alignment = .center
        topStack.spacing = 14
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.setCustomSpacing(8, after: title)
        view.addSubview(topStack)

        let menuButton = Theme.makePrimaryButton(title: "В ГЛАВНОЕ МЕНЮ", width: 244)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        view.addSubview(menuButton)

        NSLayoutConstraint.activate([
            topStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 120),
            topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            menuButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            menuButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func menuTapped() {
        if let nav = presentingViewController?.navigationController ?? presentingViewController as? UINavigationController {
            dismiss(animated: false) {
                nav.popToRootViewController(animated: true)
            }
        } else {
            dismiss(animated: true) { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}
