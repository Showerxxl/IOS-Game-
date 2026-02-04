//
//  GameScreenView.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit
import AVFoundation

protocol GameScreenViewProtocol: AnyObject {
    var presenter: GameScreenPresenterProtocol? { get set }
    func updateUI()
    func showMessage(_ message: String)
    func showCardEffect(_ cardType: CardType)
    func showSeeTheFutureCards(_ cards: [Card])
    func showDefuseOptions()
    func promptSelectPlayer(players: [Player], completion: @escaping (Player) -> Void)
    func promptSelectCard(from player: Player, completion: @escaping (CardType?) -> Void)
    func navigateToGameOver(winner: Player)
}

class GameScreenView: UIViewController {
    
    // MARK: - Properties
    var presenter: GameScreenPresenterProtocol?
    private var audioPlayer: AVAudioPlayer?
    private var selectedCardIndex: Int?
    private var selectPlayerCompletion: ((Player) -> Void)?
    private var selectCardCompletion: ((CardType?) -> Void)?
    
    // MARK: - UI Components
    private let deckView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.black.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let deckCountLabel: UILabel = {
        let label = UILabel()
        label.text = "Колода: 0"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let playersStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let currentPlayerLabel: UILabel = {
        let label = UILabel()
        label.text = "Ход игрока: "
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let handCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 10
        layout.itemSize = CGSize(width: 100, height: 140)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(CardCell.self, forCellWithReuseIdentifier: "CardCell")
        return cv
    }()
    
    private let playCardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Сыграть картой", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let drawCardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Взять карту", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let endTurnButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Завершить ход", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("⚙️", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupCollectionView()
        presenter?.viewDidLoad()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        
        view.addSubview(deckView)
        deckView.addSubview(deckCountLabel)
        view.addSubview(playersStackView)
        view.addSubview(currentPlayerLabel)
        view.addSubview(handCollectionView)
        view.addSubview(playCardButton)
        view.addSubview(drawCardButton)
        view.addSubview(endTurnButton)
        view.addSubview(settingsButton)
        view.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            deckView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            deckView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deckView.widthAnchor.constraint(equalToConstant: 100),
            deckView.heightAnchor.constraint(equalToConstant: 140),
            
            deckCountLabel.centerXAnchor.constraint(equalTo: deckView.centerXAnchor),
            deckCountLabel.centerYAnchor.constraint(equalTo: deckView.centerYAnchor),
            
            playersStackView.topAnchor.constraint(equalTo: deckView.bottomAnchor, constant: 20),
            playersStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playersStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playersStackView.heightAnchor.constraint(equalToConstant: 80),
            
            currentPlayerLabel.topAnchor.constraint(equalTo: playersStackView.bottomAnchor, constant: 20),
            currentPlayerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: currentPlayerLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            handCollectionView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            handCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            handCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            handCollectionView.heightAnchor.constraint(equalToConstant: 160),
            
            playCardButton.topAnchor.constraint(equalTo: handCollectionView.bottomAnchor, constant: 20),
            playCardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            playCardButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            playCardButton.heightAnchor.constraint(equalToConstant: 50),
            
            drawCardButton.topAnchor.constraint(equalTo: playCardButton.bottomAnchor, constant: 15),
            drawCardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            drawCardButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            drawCardButton.heightAnchor.constraint(equalToConstant: 50),
            
            endTurnButton.topAnchor.constraint(equalTo: playCardButton.bottomAnchor, constant: 15),
            endTurnButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            endTurnButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            endTurnButton.heightAnchor.constraint(equalToConstant: 50),
            
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        playCardButton.addTarget(self, action: #selector(playCardTapped), for: .touchUpInside)
        drawCardButton.addTarget(self, action: #selector(drawCardTapped), for: .touchUpInside)
        endTurnButton.addTarget(self, action: #selector(endTurnTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }
    
    private func setupCollectionView() {
        handCollectionView.delegate = self
        handCollectionView.dataSource = self
    }
    
    // MARK: - Actions
    @objc private func playCardTapped() {
        guard let index = selectedCardIndex else { return }
        presenter?.playCard(at: index)
        selectedCardIndex = nil
    }
    
    @objc private func drawCardTapped() {
        presenter?.drawCard()
    }
    
    @objc private func endTurnTapped() {
        presenter?.endTurn()
    }
    
    @objc private func settingsTapped() {
        presenter?.settingsButtonTapped()
    }
    
    private func playSound() {
        guard GameSettings.shared.soundEffectsEnabled else { return }
        // Здесь будет воспроизведение звуков
    }
}

// MARK: - GameScreenViewProtocol
extension GameScreenView: GameScreenViewProtocol {
    func updateUI() {
        guard let presenter = presenter else { return }
        
        // Обновление колоды
        deckCountLabel.text = "Колода: \(presenter.deckCount)"
        
        // Обновление игроков
        playersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for player in presenter.players {
            let playerView = createPlayerView(for: player)
            playersStackView.addArrangedSubview(playerView)
        }
        
        // Обновление текущего игрока
        if let currentPlayer = presenter.currentPlayer {
            currentPlayerLabel.text = "Ход: \(currentPlayer.name)"
            
            // Обновляем руку только для текущего игрока-человека
            if currentPlayer.type == .human {
                handCollectionView.reloadData()
                drawCardButton.isHidden = false
                playCardButton.isEnabled = selectedCardIndex != nil
            } else {
                drawCardButton.isHidden = true
                playCardButton.isEnabled = false
            }
        }
    }
    
    func showMessage(_ message: String) {
        messageLabel.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.messageLabel.text = ""
        }
    }
    
    func showCardEffect(_ cardType: CardType) {
        showMessage("Сыграна карта: \(cardType.rawValue)")
        playSound()
    }
    
    func showSeeTheFutureCards(_ cards: [Card]) {
        var message = "Следующие 3 карты:\n"
        for (index, card) in cards.enumerated() {
            message += "\(index + 1). \(card.type.rawValue)\n"
        }
        
        let alert = UIAlertController(title: "Подсмотреть грядущее", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func showDefuseOptions() {
        let alert = UIAlertController(title: "Обезвредь котёнка", message: "Куда положить взрывного котёнка?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "На верх колоды", style: .default) { [weak self] _ in
            self?.presenter?.placeExplodingKitten(at: 0)
        })
        
        alert.addAction(UIAlertAction(title: "Случайное место", style: .default) { [weak self] _ in
            let randomPosition = Int.random(in: 0...(self?.presenter?.deckCount ?? 1))
            self?.presenter?.placeExplodingKitten(at: randomPosition)
        })
        
        present(alert, animated: true)
    }
    
    func promptSelectPlayer(players: [Player], completion: @escaping (Player) -> Void) {
        self.selectPlayerCompletion = completion
        
        let alert = UIAlertController(title: "Выбор игрока", message: "Выберите игрока", preferredStyle: .actionSheet)
        
        for player in players {
            alert.addAction(UIAlertAction(title: player.name, style: .default) { [weak self] _ in
                self?.selectPlayerCompletion?(player)
                self?.selectPlayerCompletion = nil
            })
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    
    func promptSelectCard(from player: Player, completion: @escaping (CardType?) -> Void) {
        self.selectCardCompletion = completion
        
        let alert = UIAlertController(title: "Выбор карты", message: "Выберите карту у \(player.name)", preferredStyle: .actionSheet)
        
        let uniqueTypes = Set(player.hand.map { $0.type })
        for cardType in uniqueTypes {
            alert.addAction(UIAlertAction(title: cardType.rawValue, style: .default) { [weak self] _ in
                self?.selectCardCompletion?(cardType)
                self?.selectCardCompletion = nil
            })
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { [weak self] _ in
            self?.selectCardCompletion?(nil)
            self?.selectCardCompletion = nil
        })
        
        present(alert, animated: true)
    }
    
    func navigateToGameOver(winner: Player) {
        let message = winner.type == .human ? "Вы победили!" : "Победил \(winner.name)"
        
        let alert = UIAlertController(title: "Игра окончена", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Вернуться в меню", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func createPlayerView(for player: Player) -> UIView {
        let container = UIView()
        container.backgroundColor = player.isAlive ? .systemGray5 : .systemGray3
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 2
        container.layer.borderColor = presenter?.currentPlayer?.id == player.id ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
        
        let nameLabel = UILabel()
        nameLabel.text = player.name
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let cardCountLabel = UILabel()
        cardCountLabel.text = "Карт: \(player.hand.count)"
        cardCountLabel.font = UIFont.systemFont(ofSize: 12)
        cardCountLabel.textAlignment = .center
        cardCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(nameLabel)
        container.addSubview(cardCountLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            
            cardCountLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            cardCountLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            cardCountLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5)
        ])
        
        return container
    }
}

// MARK: - UICollectionViewDataSource
extension GameScreenView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return presenter?.currentPlayerHand.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CardCell", for: indexPath) as! CardCell
        if let card = presenter?.currentPlayerHand[indexPath.item] {
            cell.configure(with: card, isSelected: selectedCardIndex == indexPath.item)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension GameScreenView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCardIndex = indexPath.item
        playCardButton.isEnabled = true
        collectionView.reloadData()
    }
}

// MARK: - CardCell
class CardCell: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.black.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 5),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5)
        ])
    }
    
    func configure(with card: Card, isSelected: Bool) {
        titleLabel.text = card.type.rawValue
        containerView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.black.cgColor
        containerView.layer.borderWidth = isSelected ? 3 : 2
        containerView.backgroundColor = isSelected ? .systemBlue.withAlphaComponent(0.2) : .white
    }
}
