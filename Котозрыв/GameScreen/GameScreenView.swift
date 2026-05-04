import UIKit

enum NopeDecision {
    case played
    case declined
    case timedOut
}

protocol GameScreenViewProtocol: AnyObject {
    var presenter: GameScreenPresenterProtocol? { get set }
    func updateUI()
    func showMessage(_ message: String)
    func showCardEffect(_ cardType: CardType)
    func showSeeTheFutureCards(_ cards: [Card])
    func showDefuseOptions()
    func promptSelectPlayer(players: [Player], completion: @escaping (Player) -> Void)
    func promptSelectCard(from player: Player, completion: @escaping (CardType?) -> Void)
    func promptSelectCardType(completion: @escaping (CardType?) -> Void)
    func promptComboRequest(requesterName: String, cards: [Card], completion: @escaping (Card?) -> Void)
    func showNopeWindow(canPlayNope: Bool, completion: @escaping (NopeDecision) -> Void)
    func dismissNopeWindow()
    func navigateToGameOver(winner: Player)
    func showExplosion(playerName: String)
    func animateCardDraw(card: Card, by player: Player, revealFace: Bool, completion: @escaping () -> Void)
    func animateCardPlay(card: Card, by player: Player, completion: @escaping () -> Void)
    func animateCardTransfer(card: Card, from sender: Player, to receiver: Player,
                             revealFace: Bool, completion: @escaping () -> Void)
}

final class GameScreenView: UIViewController {

    var presenter: GameScreenPresenterProtocol?

    private var selectedIndices: [Int] = []

    // MARK: - UI top
    private let backButton    = Theme.makeCircleIconButton(systemName: "chevron.left")
    private let settingsButton = Theme.makeCircleIconButton(systemName: "gearshape.fill")

    private let turnKickerLabel = Theme.makeAccentLabel("ХОДИТ")
    private let turnNameLabel: UILabel = {
        let l = Theme.makeBodyLabel("—", size: 20)
        l.textAlignment = .center
        return l
    }()

   
    private let opponentsScroll: UIScrollView = {
        let s = UIScrollView()
        s.showsHorizontalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let opponentsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let deckButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .clear
        return b
    }()
    private let deckCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Palette.yellow
        v.layer.cornerRadius = 10
        v.layer.borderColor = Theme.Palette.ink.cgColor
        v.layer.borderWidth = 2
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.5
        v.layer.shadowRadius = 6
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let deckCaption: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "КОЛОДА · 0",
            attributes: [.kern: 2, .font: Theme.notable(11), .foregroundColor: Theme.Palette.yellow])
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let discardCard: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        v.layer.borderWidth = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let discardLabel: UILabel = {
        let l = UILabel()
        l.text = "СБРОС\nПУСТ"
        l.numberOfLines = 0
        l.font = Theme.mono(9)
        l.textColor = Theme.Palette.yellow.withAlphaComponent(0.5)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let discardCaption: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "СБРОС",
            attributes: [.kern: 2, .font: Theme.notable(11), .foregroundColor: Theme.Palette.pink])
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let messagePanel: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        v.layer.cornerRadius = 14
        v.layer.borderColor = Theme.Palette.yellow.withAlphaComponent(0.4).cgColor
        v.layer.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let messageLabel: UILabel = {
        let l = Theme.makeMonoLabel("ВАШ ХОД. СЫГРАЙТЕ КАРТУ ИЛИ ВОЗЬМИТЕ ИЗ КОЛОДЫ.", size: 11, color: .white)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let playerPanel: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let playerNameLabel: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "ВЫ",
            attributes: [.kern: 1, .font: Theme.notable(14), .foregroundColor: Theme.Palette.yellow])
        return l
    }()
    private let cardsCountLabel = Theme.makeMonoLabel("КАРТ В РУКЕ: 0", size: 10,
                                                       color: UIColor.white.withAlphaComponent(0.6))
    private let yourTurnBadge: UILabel = {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: "ВАШ ХОД",
            attributes: [.kern: 1.5, .font: Theme.notable(10), .foregroundColor: Theme.Palette.black])
        l.backgroundColor = Theme.Palette.yellow
        l.layer.cornerRadius = 12
        l.layer.masksToBounds = true
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: 80).isActive = true
        l.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return l
    }()


    private let handScroll: UIScrollView = {
        let s = UIScrollView()
        s.showsHorizontalScrollIndicator = false
        s.clipsToBounds = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let handStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 4
        s.alignment = .bottom
        s.clipsToBounds = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()


    private var discardImageView: UIImageView?

    private var nopeOverlay: UIView?
    private var nopeCountdownTimer: Timer?
    private var nopeDismissClosure: (() -> Void)?

    private let drawButton = GameScreenView.makeActionBtn(title: "ВЗЯТЬ", filled: false)
    private let playButton = GameScreenView.makeActionBtn(title: "СЫГРАТЬ", filled: true)
    private let passButton = GameScreenView.makeActionBtn(title: "ПАС", filled: false)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindActions()
        presenter?.viewDidLoad()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.styleNavigationController(self)
    }

    private func setupUI() {
        Theme.installBackground(on: view)

        view.addSubview(backButton)
        view.addSubview(settingsButton)

        let turnStack = UIStackView(arrangedSubviews: [turnKickerLabel, turnNameLabel])
        turnStack.axis = .vertical
        turnStack.alignment = .center
        turnStack.spacing = 2
        turnStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(turnStack)


        view.addSubview(opponentsScroll)
        opponentsScroll.addSubview(opponentsStack)

  
        view.addSubview(deckButton)
        deckButton.addSubview(deckCard)
        view.addSubview(deckCaption)

        view.addSubview(discardCard)
        discardCard.addSubview(discardLabel)
        view.addSubview(discardCaption)

    
        view.addSubview(messagePanel)
        messagePanel.addSubview(messageLabel)

    
        view.addSubview(playerPanel)
        let playerInfoStack = UIStackView(arrangedSubviews: [playerNameLabel, cardsCountLabel])
        playerInfoStack.axis = .vertical
        playerInfoStack.spacing = 2
        playerInfoStack.translatesAutoresizingMaskIntoConstraints = false
        playerPanel.addSubview(playerInfoStack)
        playerPanel.addSubview(yourTurnBadge)

        view.addSubview(handScroll)
        handScroll.addSubview(handStack)


        let actionsStack = UIStackView(arrangedSubviews: [drawButton, playButton, passButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 10
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(actionsStack)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            turnStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            turnStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            opponentsScroll.topAnchor.constraint(equalTo: turnStack.bottomAnchor, constant: 16),
            opponentsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            opponentsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            opponentsScroll.heightAnchor.constraint(equalToConstant: 100),

            opponentsStack.topAnchor.constraint(equalTo: opponentsScroll.topAnchor),
            opponentsStack.bottomAnchor.constraint(equalTo: opponentsScroll.bottomAnchor),
            opponentsStack.leadingAnchor.constraint(equalTo: opponentsScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            opponentsStack.trailingAnchor.constraint(equalTo: opponentsScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            opponentsStack.heightAnchor.constraint(equalTo: opponentsScroll.heightAnchor),

            deckButton.topAnchor.constraint(equalTo: opponentsScroll.bottomAnchor, constant: 28),
            deckButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -15),
            deckButton.widthAnchor.constraint(equalToConstant: 96),
            deckButton.heightAnchor.constraint(equalToConstant: 126),

            deckCard.topAnchor.constraint(equalTo: deckButton.topAnchor),
            deckCard.leadingAnchor.constraint(equalTo: deckButton.leadingAnchor),
            deckCard.widthAnchor.constraint(equalToConstant: 88),
            deckCard.heightAnchor.constraint(equalToConstant: 116),

            deckCaption.topAnchor.constraint(equalTo: deckButton.bottomAnchor, constant: 4),
            deckCaption.centerXAnchor.constraint(equalTo: deckButton.centerXAnchor),

            discardCard.topAnchor.constraint(equalTo: deckButton.topAnchor),
            discardCard.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 15),
            discardCard.widthAnchor.constraint(equalToConstant: 88),
            discardCard.heightAnchor.constraint(equalToConstant: 116),

            discardLabel.centerXAnchor.constraint(equalTo: discardCard.centerXAnchor),
            discardLabel.centerYAnchor.constraint(equalTo: discardCard.centerYAnchor),

            discardCaption.topAnchor.constraint(equalTo: discardCard.bottomAnchor, constant: 4),
            discardCaption.centerXAnchor.constraint(equalTo: discardCard.centerXAnchor),

            messagePanel.topAnchor.constraint(equalTo: deckCaption.bottomAnchor, constant: 22),
            messagePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messagePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messagePanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            messageLabel.topAnchor.constraint(equalTo: messagePanel.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: messagePanel.bottomAnchor, constant: -10),
            messageLabel.leadingAnchor.constraint(equalTo: messagePanel.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: messagePanel.trailingAnchor, constant: -14),

      
            actionsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            actionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            actionsStack.heightAnchor.constraint(equalToConstant: 52),

          
            handScroll.bottomAnchor.constraint(equalTo: actionsStack.topAnchor, constant: -10),
            handScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            handScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            handScroll.heightAnchor.constraint(equalToConstant: 100),

            handStack.topAnchor.constraint(equalTo: handScroll.topAnchor),
            handStack.bottomAnchor.constraint(equalTo: handScroll.bottomAnchor),
            handStack.leadingAnchor.constraint(equalTo: handScroll.contentLayoutGuide.leadingAnchor, constant: 12),
            handStack.trailingAnchor.constraint(equalTo: handScroll.contentLayoutGuide.trailingAnchor, constant: -12),
            handStack.heightAnchor.constraint(equalTo: handScroll.heightAnchor),


            playerPanel.bottomAnchor.constraint(equalTo: handScroll.topAnchor, constant: -10),
            playerPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            playerPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            playerPanel.heightAnchor.constraint(equalToConstant: 56),

            playerInfoStack.leadingAnchor.constraint(equalTo: playerPanel.leadingAnchor, constant: 14),
            playerInfoStack.centerYAnchor.constraint(equalTo: playerPanel.centerYAnchor),

            yourTurnBadge.trailingAnchor.constraint(equalTo: playerPanel.trailingAnchor, constant: -14),
            yourTurnBadge.centerYAnchor.constraint(equalTo: playerPanel.centerYAnchor)
        ])


        for i in 1...2 {
            let layer = UIView()
            layer.backgroundColor = Theme.Palette.yellow
            layer.layer.cornerRadius = 10
            layer.layer.borderColor = Theme.Palette.ink.cgColor
            layer.layer.borderWidth = 2
            layer.layer.shadowColor = UIColor.black.cgColor
            layer.layer.shadowOpacity = 0.4
            layer.layer.shadowRadius = 4
            layer.layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.translatesAutoresizingMaskIntoConstraints = false
            deckButton.insertSubview(layer, belowSubview: deckCard)
            NSLayoutConstraint.activate([
                layer.widthAnchor.constraint(equalToConstant: 88),
                layer.heightAnchor.constraint(equalToConstant: 116),
                layer.topAnchor.constraint(equalTo: deckButton.topAnchor, constant: CGFloat(i) * 2),
                layer.leadingAnchor.constraint(equalTo: deckButton.leadingAnchor, constant: CGFloat(i) * 2)
            ])
        }
    }

    private func bindActions() {
        backButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        deckButton.addTarget(self, action: #selector(deckTapped), for: .touchUpInside)
        drawButton.addTarget(self, action: #selector(deckTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        passButton.addTarget(self, action: #selector(passTapped), for: .touchUpInside)

        drawButton.silentTap = true
        playButton.silentTap = true
        passButton.silentTap = true
    }

    // MARK: - Actions

    @objc private func exitTapped() {
        let alert = UIAlertController(title: "Выйти из партии?",
                                      message: "Текущий прогресс будет потерян.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func settingsTapped() { presenter?.settingsButtonTapped() }
    @objc private func deckTapped()     { presenter?.drawCard() }

    @objc private func passTapped()     { presenter?.drawCard() }
    @objc private func playTapped() {
        guard !selectedIndices.isEmpty else { return }
        let indices = selectedIndices
        selectedIndices.removeAll()
        presenter?.playCards(at: indices)
    }

    @objc private func cardTapped(_ gr: UITapGestureRecognizer) {
        guard let cardView = gr.view, let presenter = presenter else { return }
        let idx = cardView.tag
        let hand = presenter.humanHand
        guard idx < hand.count else { return }

        if let pos = selectedIndices.firstIndex(of: idx) {
 
            selectedIndices.remove(at: pos)
        } else {
            let tappedType = hand[idx].type
            if selectedIndices.isEmpty {
                selectedIndices = [idx]
            } else if let firstIdx = selectedIndices.first,
                      hand[firstIdx].type == tappedType {
                if selectedIndices.count < 3 {
                    selectedIndices.append(idx)
                }
            } else {
                selectedIndices = [idx]
            }
        }
        renderHand()
    }

    // MARK: - Rendering

    private func renderHand() {
        handStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let presenter = presenter else { return }
        let hand = presenter.humanHand
        let isMyTurn = presenter.currentPlayer?.type == .human

        for (i, card) in hand.enumerated() {
            let cardView = makeCardView(type: card.type)
            cardView.tag = i
            cardView.alpha = isMyTurn ? 1.0 : 0.55
            if selectedIndices.contains(i) {
                cardView.transform = CGAffineTransform(translationX: 0, y: -14)
                if let iv = cardView.subviews.compactMap({ $0 as? UIImageView }).first {
                    iv.layer.borderColor = Theme.Palette.yellow.cgColor
                    iv.layer.borderWidth = 3
                }
                cardView.layer.shadowOpacity = 0.7
                cardView.layer.shadowRadius = 12
                cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
            }
            if isMyTurn {
                let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
                cardView.addGestureRecognizer(tap)
                cardView.isUserInteractionEnabled = true
            }
            handStack.addArrangedSubview(cardView)
        }
        
        for idx in selectedIndices where idx < handStack.arrangedSubviews.count {
            handStack.bringSubviewToFront(handStack.arrangedSubviews[idx])
        }

   
        let title: String
        switch selectedIndices.count {
        case 2: title = "ПАРА"
        case 3: title = "ТРИО"
        default: title = "СЫГРАТЬ"
        }
        playButton.setTitle(title, for: .normal)

        playButton.isEnabled = isMyTurn && !selectedIndices.isEmpty
        playButton.alpha = playButton.isEnabled ? 1.0 : 0.5
        drawButton.isEnabled = isMyTurn
        drawButton.alpha = isMyTurn ? 1.0 : 0.5
        passButton.isEnabled = isMyTurn
        passButton.alpha = isMyTurn ? 1.0 : 0.5
    }

    private func renderOpponents() {
        opponentsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let presenter = presenter else { return }
        let humanId = presenter.humanPlayer?.id
        let opps = presenter.players.filter { $0.id != humanId }
        for opp in opps {
            opponentsStack.addArrangedSubview(makeOpponentBadge(player: opp,
                isActive: presenter.currentPlayer?.id == opp.id))
        }
    }

    private func renderPlayerPanel() {
        guard let presenter = presenter else { return }
        let isMyTurn = presenter.currentPlayer?.type == .human
        playerPanel.backgroundColor = isMyTurn
            ? Theme.Palette.yellow.withAlphaComponent(0.18)
            : UIColor.black.withAlphaComponent(0.4)
        playerPanel.layer.borderColor = isMyTurn
            ? Theme.Palette.yellow.cgColor
            : Theme.Palette.yellow.withAlphaComponent(0.3).cgColor
        
        cardsCountLabel.text = "КАРТ В РУКЕ: \(presenter.humanHand.count)"
        yourTurnBadge.isHidden = !isMyTurn
    }

    private func makeCardView(type: CardType) -> UIView {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 70).isActive = true
        v.heightAnchor.constraint(equalToConstant: 92).isActive = true

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.translatesAutoresizingMaskIntoConstraints = false
        for name in type.assetCatalogImageNames {
            if let img = UIImage(named: name) { iv.image = img; break }
        }
        if iv.image == nil {
            iv.backgroundColor = Theme.Palette.yellow
        }
        v.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: v.topAnchor),
            iv.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            iv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.45
        v.layer.shadowRadius = 6
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        return v
    }

    private func makeOpponentBadge(player: Player, isActive: Bool) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 2

        if isActive {
            v.backgroundColor = Theme.Palette.yellow.withAlphaComponent(0.2)
            v.layer.borderColor = Theme.Palette.yellow.cgColor
        } else {
            v.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            v.layer.borderColor = (player.isAlive
                ? Theme.Palette.yellow.withAlphaComponent(0.35)
                : Theme.Palette.pink.withAlphaComponent(0.4)).cgColor
        }
        v.alpha = player.isAlive ? 1.0 : 0.55
        v.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let avatar = UILabel()
        avatar.text = player.isAlive ? "🐱" : "💥"
        avatar.font = .systemFont(ofSize: 22)
        avatar.backgroundColor = Theme.Palette.yellow
        avatar.layer.cornerRadius = 18
        avatar.layer.masksToBounds = true
        avatar.textAlignment = .center
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.widthAnchor.constraint(equalToConstant: 36).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let name = UILabel()
        name.attributedText = NSAttributedString(string: player.name.uppercased(),
            attributes: [.kern: 1, .font: Theme.notable(9), .foregroundColor: Theme.Palette.yellow])
        name.textAlignment = .center

        let count = Theme.makeMonoLabel(player.isAlive ? "\(player.hand.count) карт" : "ВЫБЫЛ",
                                        size: 9, color: UIColor.white.withAlphaComponent(0.7))
        count.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [avatar, name, count])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: v.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6)
        ])

        if isActive {
            let dot = UIView()
            dot.backgroundColor = Theme.Palette.yellow
            dot.layer.cornerRadius = 5
            dot.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 10),
                dot.heightAnchor.constraint(equalToConstant: 10),
                dot.topAnchor.constraint(equalTo: v.topAnchor, constant: -6),
                dot.centerXAnchor.constraint(equalTo: v.centerXAnchor)
            ])
        }
        return v
    }

    private static func makeActionBtn(title: String, filled: Bool) -> UIButton {
        let b = UIButton(type: .custom)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Theme.notable(filled ? 14 : 13)
        b.layer.cornerRadius = 26
        b.translatesAutoresizingMaskIntoConstraints = false
        if filled {
            b.backgroundColor = Theme.Palette.yellow
            b.setTitleColor(Theme.Palette.black, for: .normal)
            b.setTitleColor(Theme.Palette.black.withAlphaComponent(0.5), for: .disabled)
            b.layer.shadowColor = UIColor.black.cgColor
            b.layer.shadowOpacity = 0.25
            b.layer.shadowRadius = 8
            b.layer.shadowOffset = CGSize(width: 0, height: 4)
        } else {
            b.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            b.setTitleColor(Theme.Palette.yellow, for: .normal)
            b.setTitleColor(Theme.Palette.yellow.withAlphaComponent(0.4), for: .disabled)
            b.layer.borderColor = Theme.Palette.yellow.cgColor
            b.layer.borderWidth = 2
        }
        return b
    }
}

// MARK: - GameScreenViewProtocol

extension GameScreenView: GameScreenViewProtocol {
    func updateUI() {
        guard let presenter = presenter else { return }
        deckCaption.attributedText = NSAttributedString(string: "КОЛОДА · \(presenter.deckCount)",
            attributes: [.kern: 2, .font: Theme.notable(11), .foregroundColor: Theme.Palette.yellow])
        if let cur = presenter.currentPlayer {
            turnNameLabel.text = cur.name.uppercased()
        } else {
            turnNameLabel.text = "—"
        }
        renderOpponents()
        renderPlayerPanel()
        renderHand()

        if let top = presenter.topDiscardCard {
            setDiscardCard(type: top.type)
        }
    }

    func showMessage(_ message: String) {
        messageLabel.text = message
    }

    func showCardEffect(_ cardType: CardType) {
        showMessage("Сыграно: \(cardType.rawValue)")
    }

    func showSeeTheFutureCards(_ cards: [Card]) {
        showSeeTheFutureCardsCustom(cards)
    }

    func showDefuseOptions() {
        let deckCount = presenter?.deckCount ?? 0
        showDefusePlacementOverlay(deckCount: deckCount) { [weak self] position in
            self?.presenter?.placeExplodingKitten(at: position)
        }
    }

    func promptSelectPlayer(players: [Player], completion: @escaping (Player) -> Void) {
        promptSelectPlayerCustom(players: players, completion: completion)
    }

    func promptSelectCard(from player: Player, completion: @escaping (CardType?) -> Void) {
        promptSelectCardCustom(from: player, completion: completion)
    }

    func promptSelectCardType(completion: @escaping (CardType?) -> Void) {
        promptSelectCardTypeCustom(completion: completion)
    }

    func promptComboRequest(requesterName: String, cards: [Card], completion: @escaping (Card?) -> Void) {
        promptComboRequestCustom(requesterName: requesterName, cards: cards, completion: completion)
    }

    // MARK: - Nope Window

    func showNopeWindow(canPlayNope: Bool, completion: @escaping (NopeDecision) -> Void) {
        nopeOverlay?.removeFromSuperview()
        nopeCountdownTimer?.invalidate()

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let panel = UIView()
        panel.backgroundColor = Theme.Palette.ink
        panel.layer.cornerRadius = 22
        panel.layer.borderColor = Theme.Palette.yellow.cgColor
        panel.layer.borderWidth = 2
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.6
        panel.layer.shadowRadius = 16
        panel.layer.shadowOffset = CGSize(width: 0, height: 8)
        panel.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 280)
        ])

        let questionLabel = Theme.makeTitleLabel("НЕТЬ?", size: 28)

        let countdownLabel = UILabel()
        countdownLabel.text = "5"
        countdownLabel.font = Theme.notable(64)
        countdownLabel.textColor = Theme.Palette.yellow
        countdownLabel.textAlignment = .center

        let nopeButton = Theme.makePrimaryButton(title: "НЕТЬ!", width: 200)
        nopeButton.isEnabled = canPlayNope
        nopeButton.alpha = canPlayNope ? 1.0 : 0.35
        nopeButton.silentTap = true

        let declineButton = UIButton(type: .system)
        declineButton.setAttributedTitle(NSAttributedString(
            string: "Я НЕ ХОЧУ ИГРАТЬ КАРТУ НЕТЬ",
            attributes: [.font: Theme.notable(11),
                         .foregroundColor: Theme.Palette.pink,
                         .kern: 2,
                         .underlineStyle: NSUnderlineStyle.single.rawValue]
        ), for: .normal)
        declineButton.titleLabel?.numberOfLines = 0
        declineButton.titleLabel?.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [questionLabel, countdownLabel, nopeButton, declineButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -28),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20)
        ])

        nopeOverlay = overlay
        view.bringSubviewToFront(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }

        var secondsLeft = 5
        var fired = false

        let dismiss = { [weak self, weak overlay] (decision: NopeDecision) in
            guard !fired else { return }
            fired = true
            self?.nopeCountdownTimer?.invalidate()
            self?.nopeCountdownTimer = nil
            self?.nopeDismissClosure = nil
            UIView.animate(withDuration: 0.2, animations: {
                overlay?.alpha = 0
            }, completion: { _ in
                overlay?.removeFromSuperview()
                if self?.nopeOverlay === overlay { self?.nopeOverlay = nil }
                completion(decision)
            })
        }


        nopeDismissClosure = { dismiss(.timedOut) }

        nopeButton.addAction(UIAction { _ in dismiss(.played) }, for: .touchUpInside)
        declineButton.addAction(UIAction { _ in dismiss(.declined) }, for: .touchUpInside)

        nopeCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak countdownLabel] _ in
            secondsLeft -= 1
            countdownLabel?.text = "\(secondsLeft)"
            if secondsLeft <= 0 { dismiss(.timedOut) }
        }
    }

    func dismissNopeWindow() {
        nopeDismissClosure?()
        nopeDismissClosure = nil
    }

    // MARK: - Анимации

    func animateCardDraw(card: Card, by player: Player, revealFace: Bool, completion: @escaping () -> Void) {
        SoundManager.shared.playTakeCard()
        view.layoutIfNeeded()

       
        let startCenter = deckButton.convert(deckCard.center, to: view)


        let endCenter = endPosition(for: player)

       
        let flying = makeFlyingCard()
        flying.bounds = deckCard.bounds
        flying.center = startCenter
        view.addSubview(flying)

     
        pulseDeck()

 
        let mid = CGPoint(
            x: (startCenter.x + endCenter.x) / 2,
            y: min(startCenter.y, endCenter.y) - 60
        )

        UIView.animateKeyframes(withDuration: 0.55, delay: 0,
                                options: [.calculationModeCubic],
                                animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
                flying.center = mid
                flying.transform = CGAffineTransform(rotationAngle: .pi / 12)
                    .scaledBy(x: 1.05, y: 1.05)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                flying.center = endCenter
                let rot: CGFloat = (player.type == .human) ? 0 : .pi / 14
                let scale: CGFloat = (player.type == .human) ? 1.0 : 0.75
                flying.transform = CGAffineTransform(rotationAngle: rot)
                    .scaledBy(x: scale, y: scale)
            }
        }, completion: { _ in
            if revealFace, player.type == .human {
                self.flipCard(flying, to: card.type) {
                    UIView.animate(withDuration: 0.18, delay: 0.15,
                                   options: [.curveEaseIn], animations: {
                        flying.alpha = 0
                        flying.transform = flying.transform.scaledBy(x: 0.85, y: 0.85)
                    }, completion: { _ in
                        flying.removeFromSuperview()
                        completion()
                    })
                }
            } else {
                UIView.animate(withDuration: 0.18, animations: {
                    flying.alpha = 0
                }, completion: { _ in
                    flying.removeFromSuperview()
                    completion()
                })
            }
        })
    }

    func animateCardPlay(card: Card, by player: Player, completion: @escaping () -> Void) {
        if card.type == .shuffle {
            SoundManager.shared.playShuffle()
        } else {
            SoundManager.shared.playMew()
        }
        view.layoutIfNeeded()

        let startCenter = startPositionForPlay(by: player)
        let endCenter = view.convert(discardCard.center, from: discardCard.superview)

        let flying = makeFaceCard(type: card.type)
        flying.bounds = CGRect(x: 0, y: 0, width: 88, height: 116)
        flying.center = startCenter
        flying.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        view.addSubview(flying)

        UIView.animateKeyframes(withDuration: 0.5, delay: 0,
                                options: [.calculationModeCubic],
                                animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
                flying.center = CGPoint(
                    x: (startCenter.x + endCenter.x) / 2,
                    y: min(startCenter.y, endCenter.y) - 50
                )
                flying.transform = CGAffineTransform(rotationAngle: -.pi / 16).scaledBy(x: 1.1, y: 1.1)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                flying.center = endCenter
                flying.transform = CGAffineTransform(rotationAngle: .pi / 24).scaledBy(x: 1.0, y: 1.0)
            }
        }, completion: { _ in

            self.setDiscardCard(type: card.type)
            flying.removeFromSuperview()
            completion()
        })
    }

 
    private func setDiscardCard(type: CardType) {
        discardLabel.isHidden = true
        let iv: UIImageView
        if let existing = discardImageView {
            iv = existing
        } else {
            iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 10
            iv.translatesAutoresizingMaskIntoConstraints = false
            discardCard.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: discardCard.topAnchor),
                iv.bottomAnchor.constraint(equalTo: discardCard.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: discardCard.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: discardCard.trailingAnchor)
            ])
            discardImageView = iv
        }
        for name in type.assetCatalogImageNames {
            if let img = UIImage(named: name) {
                UIView.transition(with: iv, duration: 0.2, options: [.transitionCrossDissolve],
                                  animations: { iv.image = img }, completion: nil)
                break
            }
        }
        discardCard.layer.borderColor = Theme.Palette.yellow.cgColor
        discardCard.layer.borderWidth = 2
        discardCard.backgroundColor = Theme.Palette.ink.withAlphaComponent(0.4)
    }

    private func endPosition(for player: Player) -> CGPoint {
        if player.type == .human {
            return view.convert(CGPoint(x: handScroll.bounds.midX, y: handScroll.bounds.midY),
                                from: handScroll)
        }
       
        let humanId = presenter?.humanPlayer?.id
        let opps = (presenter?.players ?? []).filter { $0.id != humanId }
        if let idx = opps.firstIndex(where: { $0.id == player.id }),
           idx < opponentsStack.arrangedSubviews.count {
            let badge = opponentsStack.arrangedSubviews[idx]
            return view.convert(CGPoint(x: badge.bounds.midX, y: badge.bounds.midY), from: badge)
        }
        return view.center
    }

    private func startPositionForPlay(by player: Player) -> CGPoint {
        if player.type == .human {
            return view.convert(CGPoint(x: handScroll.bounds.midX, y: handScroll.bounds.midY - 30),
                                from: handScroll)
        }
        return endPosition(for: player)
    }

    func animateCardTransfer(card: Card, from sender: Player, to receiver: Player,
                             revealFace: Bool, completion: @escaping () -> Void) {
        view.layoutIfNeeded()

        let startCenter = endPosition(for: sender)
        let endCenter   = endPosition(for: receiver)


        let flying = makeFlyingCard()
        flying.bounds = CGRect(x: 0, y: 0, width: 76, height: 100)
        flying.center = startCenter
        flying.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        view.addSubview(flying)

       
        let mid = CGPoint(
            x: (startCenter.x + endCenter.x) / 2,
            y: min(startCenter.y, endCenter.y) - 70
        )

        UIView.animateKeyframes(withDuration: 0.55, delay: 0,
                                options: [.calculationModeCubic],
                                animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
                flying.center = mid
                flying.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                flying.center = mid
            }
        }, completion: { _ in
            if revealFace {
             
                self.flipCard(flying, to: card.type) {
                    UIView.animate(withDuration: 0.25, delay: 0.6, options: [],
                                   animations: {
                        flying.center = endCenter
                        flying.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                        flying.alpha = 0.0
                    }, completion: { _ in
                        flying.removeFromSuperview()
                        completion()
                    })
                }
            } else {
                UIView.animate(withDuration: 0.25, animations: {
                    flying.center = endCenter
                    flying.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                    flying.alpha = 0.0
                }, completion: { _ in
                    flying.removeFromSuperview()
                    completion()
                })
            }
        })
    }

    private func makeFlyingCard() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Palette.yellow
        v.layer.cornerRadius = 10
        v.layer.borderColor = Theme.Palette.ink.cgColor
        v.layer.borderWidth = 2
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.5
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        return v
    }

    private func makeFaceCard(type: CardType) -> UIView {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = false
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.5
        v.layer.shadowRadius = 8
        v.layer.shadowOffset = CGSize(width: 0, height: 6)

        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.translatesAutoresizingMaskIntoConstraints = false
        for name in type.assetCatalogImageNames {
            if let img = UIImage(named: name) { iv.image = img; break }
        }
        if iv.image == nil { iv.backgroundColor = Theme.Palette.yellow }
        v.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: v.topAnchor),
            iv.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            iv.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: v.trailingAnchor)
        ])
        return v
    }

    private func flipCard(_ card: UIView, to type: CardType, completion: @escaping () -> Void) {
        UIView.transition(with: card, duration: 0.35,
                          options: [.transitionFlipFromRight, .allowAnimatedContent],
                          animations: {
            card.subviews.forEach { $0.removeFromSuperview() }
            card.backgroundColor = .clear

            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 10
            iv.translatesAutoresizingMaskIntoConstraints = false
            for name in type.assetCatalogImageNames {
                if let img = UIImage(named: name) { iv.image = img; break }
            }
            card.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: card.topAnchor),
                iv.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: card.trailingAnchor)
            ])
            card.layer.borderWidth = 0
        }, completion: { _ in completion() })
    }

    private func pulseDeck() {
        UIView.animate(withDuration: 0.12, animations: {
            self.deckCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.6,
                           options: [],
                           animations: {
                self.deckCard.transform = .identity
            })
        })
    }

    func navigateToGameOver(winner: Player) {
        let isHuman = winner.type == .human
        let gameOver = GameOverView(isWinner: isHuman, winnerName: winner.name)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.present(gameOver, animated: true)
        }
    }

    func showExplosion(playerName: String) {
        showExplosionOverlay(playerName: playerName)
    }
}
