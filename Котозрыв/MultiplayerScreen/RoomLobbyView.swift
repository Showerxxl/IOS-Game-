import UIKit

final class RoomLobbyView: UIViewController {

    private let roomId:     String
    private let myPlayerId: String
    private let isHost:     Bool

    private var players: [RoomPlayerInfo] = []
    private var pollTimer: Timer?

    // MARK: - UI

    private let backButton   = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let gearButton   = Theme.makeCircleIconButton(systemName: "gearshape.fill")
    private let titleLabel   = Theme.makeTitleLabel("КОМНАТА", size: 36)
    private lazy var subtitleLabel = Theme.makeAccentLabel(isHost ? "ВЫ ХОЗЯИН" : "ГОСТЬ", size: 10)

    private let codeCard: UIView
    private let playersPanel: UIView
    private let playersStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 6
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private lazy var countLabel: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "0/5",
            attributes: [.font: Theme.notable(12), .foregroundColor: Theme.Palette.yellow])
        return l
    }()
    private let startButton = Theme.makePrimaryButton(title: "СТАРТ ПАРТИИ", width: 244)
    private let statusLabel: UILabel = {
        let l = Theme.makeMonoLabel("Ожидание игроков...", size: 11, color: UIColor.white.withAlphaComponent(0.6))
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let leaveButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setAttributedTitle(NSAttributedString(string: "ПОКИНУТЬ КОМНАТУ",
            attributes: [.kern: 2, .font: Theme.notable(11), .foregroundColor: Theme.Palette.pink]),
            for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Init

    init(roomId: String, myPlayerId: String, isHost: Bool) {
        self.roomId     = roomId
        self.myPlayerId = myPlayerId
        self.isHost     = isHost
        self.codeCard   = RoomLobbyView.makeCodeCard(code: roomId)
        self.playersPanel = RoomLobbyView.makePanelShell()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        listenForGameStart()
        startPolling()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopPolling()
    }

    // MARK: - Server

    private func listenForGameStart() {
        NetworkClient.shared.onEvent = { [weak self] event, data in
            guard let self = self else { return }
            if event == "gameStarted" {
                self.stopPolling()
                self.pushGameScreen()
            }
            if event == "playerLeft" {
                self.refreshRoom()
            }
        }
    }

    private func startPolling() {
        refreshRoom()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refreshRoom()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshRoom() {
        NetworkClient.shared.getRoomInfo(roomId: roomId) { [weak self] result in
            guard let self = self else { return }
            if case .success(let room) = result {
                self.players = room.players
                self.updatePlayersUI()
                if room.status == "playing" { self.pushGameScreen() }
            }
        }
    }

    private func pushGameScreen() {
        guard navigationController?.topViewController === self else { return }
        let gameVC = GameScreenRouter.createMultiplayerModule(
            myPlayerId: myPlayerId, roomId: roomId)
        navigationController?.pushViewController(gameVC, animated: true)
    }

    // MARK: - UI setup

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(backButton)
        view.addSubview(gearButton)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 6
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)

        view.addSubview(codeCard)
        view.addSubview(playersPanel)
        playersPanel.addSubview(playersStack)

        view.addSubview(statusLabel)

        if isHost { view.addSubview(startButton) }
        view.addSubview(leaveButton)

        let kicker = UILabel()
        kicker.attributedText = NSAttributedString(string: "ИГРОКИ",
            attributes: [.kern: 2, .font: Theme.notable(10), .foregroundColor: Theme.Palette.pink])

        let header = UIStackView(arrangedSubviews: [kicker, UIView(), countLabel])
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.translatesAutoresizingMaskIntoConstraints = false
        playersPanel.addSubview(header)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            gearButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            gearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            codeCard.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 30),
            codeCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            codeCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            playersPanel.topAnchor.constraint(equalTo: codeCard.bottomAnchor, constant: 18),
            playersPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            playersPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            header.topAnchor.constraint(equalTo: playersPanel.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: playersPanel.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: playersPanel.trailingAnchor, constant: -14),

            playersStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            playersStack.bottomAnchor.constraint(equalTo: playersPanel.bottomAnchor, constant: -12),
            playersStack.leadingAnchor.constraint(equalTo: playersPanel.leadingAnchor, constant: 14),
            playersStack.trailingAnchor.constraint(equalTo: playersPanel.trailingAnchor, constant: -14),

            statusLabel.topAnchor.constraint(equalTo: playersPanel.bottomAnchor, constant: 14),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leaveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            leaveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        if isHost {
            NSLayoutConstraint.activate([
                startButton.bottomAnchor.constraint(equalTo: leaveButton.topAnchor, constant: -8),
                startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
        }
    }

    private func bindActions() {
        backButton.addTarget(self, action: #selector(leaveTapped), for: .touchUpInside)
        leaveButton.addTarget(self, action: #selector(leaveTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    // MARK: - Dynamic player list

    private func updatePlayersUI() {
        countLabel.attributedText = NSAttributedString(string: "\(players.count)/5",
            attributes: [.font: Theme.notable(12), .foregroundColor: Theme.Palette.yellow])

        playersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for p in players {
            let isMe   = p.player_id == myPlayerId
            let isHost = players.first?.player_id == p.player_id
            playersStack.addArrangedSubview(makePlayerRow(name: p.name, isMe: isMe, isHost: isHost))
        }
        for _ in players.count..<5 {
            playersStack.addArrangedSubview(makeEmptyRow())
        }

        let needed = 2 - players.count
        if isHost {
            startButton.isEnabled = players.count >= 2
            startButton.alpha     = players.count >= 2 ? 1.0 : 0.45
            statusLabel.text = players.count >= 2
                ? "Можно начинать! Нажмите СТАРТ."
                : "Ждём ещё \(needed) игрок(а)..."
        } else {
            statusLabel.text = "Ожидание хозяина комнаты..."
        }
    }

    // MARK: - Actions

    @objc private func leaveTapped() {
        stopPolling()
        NetworkClient.shared.disconnect()
        navigationController?.popViewController(animated: true)
    }

    @objc private func startTapped() {
        startButton.isEnabled = false
        NetworkClient.shared.startGame(roomId: roomId, playerId: myPlayerId) { [weak self] result in
            if case .failure(let e) = result {
                self?.startButton.isEnabled = true
                let alert = UIAlertController(title: "Ошибка", message: e.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }

    // MARK: - Row factories

    private func makePlayerRow(name: String, isMe: Bool, isHost: Bool) -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Palette.yellow.withAlphaComponent(0.08)
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false

        let avatarLabel = UILabel()
        avatarLabel.text = isMe ? "😸" : "🐱"
        avatarLabel.font = .systemFont(ofSize: 18)
        avatarLabel.backgroundColor = Theme.Palette.yellow
        avatarLabel.layer.cornerRadius = 16
        avatarLabel.layer.masksToBounds = true
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        avatarLabel.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let nameLabel = UILabel()
        nameLabel.attributedText = NSAttributedString(
            string: (isMe ? "\(name) (Вы)" : name).uppercased(),
            attributes: [.kern: 1, .font: Theme.notable(12), .foregroundColor: Theme.Palette.yellow])

        let meta = UILabel()
        meta.text = isHost ? "ХОЗЯИН · ✓ ГОТОВ" : "✓ ГОТОВ"
        meta.font = Theme.mono(9)
        meta.textColor = UIColor.white.withAlphaComponent(0.55)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, meta])
        textStack.axis = .vertical; textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [avatarLabel, textStack])
        row.axis = .horizontal; row.spacing = 10; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
        ])
        return v
    }

    private func makeEmptyRow() -> UIView {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        v.layer.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.attributedText = NSAttributedString(string: "ОЖИДАНИЕ...",
            attributes: [.kern: 1, .font: Theme.notable(12),
                         .foregroundColor: UIColor.white.withAlphaComponent(0.3)])
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 52),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 48),
        ])
        return v
    }

    // MARK: - Static factories

    private static func makeCodeCard(code: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = Theme.Palette.yellow
        card.layer.cornerRadius = 22
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.25
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 4)

        let kicker = UILabel()
        kicker.attributedText = NSAttributedString(string: "КОД КОМНАТЫ",
            attributes: [.kern: 3, .font: Theme.notable(9),
                         .foregroundColor: Theme.Palette.black.withAlphaComponent(0.6)])

        let codeLabel = UILabel()
        codeLabel.attributedText = NSAttributedString(string: code,
            attributes: [.kern: 6, .font: Theme.notable(38),
                         .foregroundColor: Theme.Palette.black])

        let copyBtn = UIButton(type: .custom)
        copyBtn.setImage(UIImage(systemName: "doc.on.doc",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)), for: .normal)
        copyBtn.tintColor = Theme.Palette.yellow
        copyBtn.backgroundColor = Theme.Palette.black
        copyBtn.layer.cornerRadius = 20
        copyBtn.translatesAutoresizingMaskIntoConstraints = false
        copyBtn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        copyBtn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        copyBtn.addAction(UIAction { _ in UIPasteboard.general.string = code }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [codeLabel, UIView(), copyBtn])
        row.axis = .horizontal; row.alignment = .center

        let footer = UILabel()
        footer.text = "ПОДЕЛИТЕСЬ КОДОМ С ДРУЗЬЯМИ"
        footer.font = Theme.mono(10)
        footer.textColor = Theme.Palette.black.withAlphaComponent(0.6)

        let stack = UIStackView(arrangedSubviews: [kicker, row, footer])
        stack.axis = .vertical; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        return card
    }

    private static func makePanelShell() -> UIView {
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        panel.layer.cornerRadius = 18
        panel.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        panel.layer.borderWidth = 1
        return panel
    }
}
