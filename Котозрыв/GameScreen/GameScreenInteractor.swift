//
//  GameScreenInteractor.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol GameScreenInteractorProtocol: AnyObject {
    var presenter: GameScreenInteractorOutputProtocol? { get set }
    func setupGame(gameState: GameState)
    func drawCard(for player: Player, gameState: GameState)
    func playCard(card: Card, by player: Player, gameState: GameState)
    func placeExplodingKittenInDeck(at position: Int, gameState: GameState)
}

protocol GameScreenInteractorOutputProtocol: AnyObject {
    func cardDrawn(card: Card, by player: Player)
    func playerExploded(_ player: Player, hasDefuse: Bool)
    func showSeeTheFutureCards(_ cards: [Card])
    func promptPlayerSelection(availablePlayers: [Player], completion: @escaping (Player) -> Void)
    func promptCardSelection(from player: Player, completion: @escaping (CardType?) -> Void)
    func cardEffectApplied(message: String)
}

class GameScreenInteractor {
    weak var presenter: GameScreenInteractorOutputProtocol?
    
    // MARK: - Game Setup
    private func createInitialDeck(playerCount: Int) -> [Card] {
        var deck: [Card] = []
        
        // Добавляем карты согласно правилам
        // Неть - 5 карт
        for _ in 0..<5 {
            deck.append(Card(type: .nope))
        }
        
        // Нападай - 4 карты
        for _ in 0..<4 {
            deck.append(Card(type: .attack))
        }
        
        // Слиняй - 4 карты
        for _ in 0..<4 {
            deck.append(Card(type: .skip))
        }
        
        // Подлижись - 4 карты
        for _ in 0..<4 {
            deck.append(Card(type: .favor))
        }
        
        // Затасуй - 4 карты
        for _ in 0..<4 {
            deck.append(Card(type: .shuffle))
        }
        
        // Подсмотри грядущее - 5 карт
        for _ in 0..<5 {
            deck.append(Card(type: .seeTheFuture))
        }
        
        // Кошкокарты - по 4 каждого вида
        let catCards: [CardType] = [.catCard1, .catCard2, .catCard3, .catCard4, .catCard5]
        for catType in catCards {
            for _ in 0..<4 {
                deck.append(Card(type: catType))
            }
        }
        
        return deck.shuffled()
    }
    
    private func dealInitialCards(to players: [Player], from deck: inout [Card]) {
        // Раздаем каждому игроку по 7 карт + 1 Обезвредь
        for player in players {
            // 7 карт из колоды
            for _ in 0..<7 {
                if !deck.isEmpty {
                    let card = deck.removeFirst()
                    player.addCard(card)
                }
            }
            
            // 1 Обезвредь карта
            player.addCard(Card(type: .defuse))
        }
    }
    
    private func addDefuseCards(to deck: inout [Card], playerCount: Int) {
        // Добавляем оставшиеся Обезвредь карты в колоду
        // Для игры вдвоем и втроем - 2 карты, для остальных - больше
        let defuseCount = playerCount <= 3 ? 2 : (6 - playerCount)
        for _ in 0..<defuseCount {
            deck.append(Card(type: .defuse))
        }
    }
    
    private func addExplodingKittens(to deck: inout [Card], playerCount: Int) {
        // Добавляем взрывных котят (количество игроков - 1)
        for _ in 0..<(playerCount - 1) {
            deck.append(Card(type: .explodingKitten))
        }
    }
    
    // MARK: - Card Effects
    private func applyCardEffect(card: Card, player: Player, gameState: GameState) {
        switch card.type {
        case .attack:
            handleAttackCard(player: player, gameState: gameState)
            
        case .skip:
            handleSkipCard(player: player, gameState: gameState)
            
        case .favor:
            handleFavorCard(player: player, gameState: gameState)
            
        case .shuffle:
            handleShuffleCard(gameState: gameState)
            
        case .seeTheFuture:
            handleSeeTheFutureCard(gameState: gameState)
            
        case .nope:
            presenter?.cardEffectApplied(message: "Неть! Действие отменено")
            
        default:
            break
        }
    }
    
    private func handleAttackCard(player: Player, gameState: GameState) {
        gameState.nextPlayer()
        if let nextPlayer = gameState.currentPlayer {
            nextPlayer.turnsRemaining += 2
            presenter?.cardEffectApplied(message: "\(nextPlayer.name) должен сходить дважды!")
        }
    }
    
    private func handleSkipCard(player: Player, gameState: GameState) {
        if player.turnsRemaining > 0 {
            player.turnsRemaining -= 1
        }
        presenter?.cardEffectApplied(message: "\(player.name) пропускает ход")
    }
    
    private func handleFavorCard(player: Player, gameState: GameState) {
        let otherPlayers = gameState.players.filter { $0.id != player.id && $0.isAlive && !$0.hand.isEmpty }
        
        guard !otherPlayers.isEmpty else {
            presenter?.cardEffectApplied(message: "Нет игроков, у которых можно взять карту")
            return
        }
        
        presenter?.promptPlayerSelection(availablePlayers: otherPlayers) { [weak self] selectedPlayer in
            if let randomCard = selectedPlayer.hand.randomElement(),
               let removedCard = selectedPlayer.removeCard(randomCard) {
                player.addCard(removedCard)
                self?.presenter?.cardEffectApplied(message: "\(player.name) взял карту у \(selectedPlayer.name)")
            }
        }
    }
    
    private func handleShuffleCard(gameState: GameState) {
        gameState.deck.shuffle()
        presenter?.cardEffectApplied(message: "Колода перетасована")
    }
    
    private func handleSeeTheFutureCard(gameState: GameState) {
        let cardsToShow = Array(gameState.deck.prefix(3))
        presenter?.showSeeTheFutureCards(cardsToShow)
    }
}

// MARK: - GameScreenInteractorProtocol
extension GameScreenInteractor: GameScreenInteractorProtocol {
    func setupGame(gameState: GameState) {
        // Создаем игроков
        let playerCount = gameState.gameMode.totalPlayers
        
        // Добавляем человека
        let humanPlayer = Player(name: "Игрок", type: .human)
        gameState.players.append(humanPlayer)
        
        // Добавляем ИИ
        if case .singlePlayer(let aiCount) = gameState.gameMode {
            for i in 1...aiCount {
                let aiPlayer = Player(name: "ИИ \(i)", type: .ai)
                gameState.players.append(aiPlayer)
            }
        }
        
        // Создаем колоду
        var deck = createInitialDeck(playerCount: playerCount)
        
        // Раздаем карты
        dealInitialCards(to: gameState.players, from: &deck)
        
        // Добавляем оставшиеся Обезвредь карты
        addDefuseCards(to: &deck, playerCount: playerCount)
        
        // Добавляем взрывных котят
        addExplodingKittens(to: &deck, playerCount: playerCount)
        
        // Перемешиваем и сохраняем колоду
        deck.shuffle()
        gameState.deck = deck
        
        // Устанавливаем первого игрока
        gameState.currentPlayerIndex = 0
    }
    
    func drawCard(for player: Player, gameState: GameState) {
        guard !gameState.deck.isEmpty else {
            presenter?.cardEffectApplied(message: "Колода пуста")
            return
        }
        
        let card = gameState.deck.removeFirst()
        
        if card.type == .explodingKitten {
            // Проверяем, есть ли у игрока Обезвредь карта
            let hasDefuse = player.hasCard(ofType: .defuse)
            
            if hasDefuse {
                // Удаляем Обезвредь карту из руки
                if let defuseCard = player.getCards(ofType: .defuse).first {
                    _ = player.removeCard(defuseCard)
                    gameState.discardPile.append(defuseCard)
                }
            }
            
            presenter?.playerExploded(player, hasDefuse: hasDefuse)
        } else {
            player.addCard(card)
            presenter?.cardDrawn(card: card, by: player)
        }
    }
    
    func playCard(card: Card, by player: Player, gameState: GameState) {
        applyCardEffect(card: card, player: player, gameState: gameState)
    }
    
    func placeExplodingKittenInDeck(at position: Int, gameState: GameState) {
        let explodingKitten = Card(type: .explodingKitten)
        let safePosition = min(max(0, position), gameState.deck.count)
        gameState.deck.insert(explodingKitten, at: safePosition)
    }
}
