import UIKit

final class MultiplayerLobbyView: UIViewController {

    // MARK: - UI
    private let backButton  = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let titleLabel  = Theme.makeTitleLabel("ОНЛАЙН", size: 42)
    private let subtitleLbl = Theme.makeAccentLabel("ИГРА С ДРУЗЬЯМИ")

    private lazy var createCard = MultiplayerLobbyView.makeActionCard(
        iconName: "plus", title: "СОЗДАТЬ КОМНАТУ",
        subtitle: "ПОЛУЧИТЕ КОД И ПРИГЛАСИТЕ ДРУЗЕЙ",
        filled: true)

    private lazy var joinCard = MultiplayerLobbyView.makeActionCard(
        iconName: "arrow.right", title: "ПРИСОЕДИНИТЬСЯ",
        subtitle: "ВВЕДИТЕ 6-ЗНАЧНЫЙ КОД КОМНАТЫ",
        filled: false)

    private let hintBox: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        v.layer.cornerRadius = 14
        v.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        v.layer.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString(
            string: "ОТ 2 ДО 5 ИГРОКОВ В КОМНАТЕ.\nПАРТИЯ НАЧИНАЕТСЯ, КОГДА ХОЗЯИН НАЖМЁТ «СТАРТ».",
            attributes: [
                .font: Theme.mono(10),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                .kern: 0.5
            ])
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: v.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16)
        ])
        return v
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(backButton)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLbl])
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 8
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)

        view.addSubview(createCard)
        view.addSubview(joinCard)
        view.addSubview(hintBox)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            createCard.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 60),
            createCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            createCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            joinCard.topAnchor.constraint(equalTo: createCard.bottomAnchor, constant: 18),
            joinCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            joinCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            hintBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            hintBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            hintBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }

    private func bindActions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        let createTap = UITapGestureRecognizer(target: self, action: #selector(createTapped))
        createCard.addGestureRecognizer(createTap)
        let joinTap = UITapGestureRecognizer(target: self, action: #selector(joinTapped))
        joinCard.addGestureRecognizer(joinTap)
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    @objc private func createTapped() {
        askForName { [weak self] name in
            guard let self = self else { return }
            self.showSpinner(true)
            NetworkClient.shared.createRoom(maxPlayers: 5) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let e):
                    self.showSpinner(false)
                    self.showError(e.localizedDescription)
                case .success(let room):
                    NetworkClient.shared.joinRoom(roomId: room.room_id, name: name) { [weak self] result in
                        guard let self = self else { return }
                        self.showSpinner(false)
                        switch result {
                        case .failure(let e): self.showError(e.localizedDescription)
                        case .success(let join):
                            NetworkClient.shared.connectWebSocket(
                                playerId: join.player_id, roomId: room.room_id)
                            let lobby = RoomLobbyView(
                                roomId: room.room_id,
                                myPlayerId: join.player_id,
                                isHost: true)
                            self.navigationController?.pushViewController(lobby, animated: true)
                        }
                    }
                }
            }
        }
    }

    @objc private func joinTapped() {
        let join = JoinRoomView()
        navigationController?.pushViewController(join, animated: true)
    }

    // MARK: - Helpers

    private func askForName(completion: @escaping (String) -> Void) {
        let overlay = NameInputOverlay(onSubmit: { name in
            completion(name)
        })
        overlay.present(in: view)
    }

    private func showSpinner(_ show: Bool) {
        if show {
            let overlay = UIView()
            overlay.tag = 9999
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = Theme.Palette.yellow
            spinner.startAnimating()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(spinner)
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            ])
        } else {
            view.viewWithTag(9999)?.removeFromSuperview()
        }
    }

    private func showError(_ msg: String) {
        let alert = UIAlertController(title: "Ошибка", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private static func makeActionCard(iconName: String, title: String, subtitle: String, filled: Bool) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 22

        if filled {
            card.backgroundColor = Theme.Palette.yellow
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOpacity = 0.25
            card.layer.shadowRadius = 8
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
        } else {
            card.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            card.layer.borderColor = Theme.Palette.yellow.cgColor
            card.layer.borderWidth = 2
        }

        let icon = UIImageView(image: UIImage(systemName: iconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)))
        icon.tintColor = filled ? Theme.Palette.yellow : Theme.Palette.yellow
        icon.contentMode = .center
        icon.backgroundColor = filled ? Theme.Palette.black : .clear
        icon.layer.cornerRadius = 28
        if !filled {
            icon.layer.borderColor = Theme.Palette.yellow.cgColor
            icon.layer.borderWidth = 2
        }
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: title,
            attributes: [.kern: 1, .font: Theme.notable(15),
                         .foregroundColor: filled ? Theme.Palette.black : Theme.Palette.yellow])

        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = Theme.mono(10)
        subLabel.textColor = filled
            ? UIColor(red: 9/255, green: 8/255, blue: 8/255, alpha: 0.7)
            : UIColor.white.withAlphaComponent(0.65)
        subLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(textStack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 56),
            icon.heightAnchor.constraint(equalToConstant: 56),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
        ])
        card.isUserInteractionEnabled = true
        return card
    }
}
