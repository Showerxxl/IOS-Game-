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
    func cardStolen(card: Card, from sender: Player, to receiver: Player)
    func promptCardFromHand(of target: Player, requesterName: String, completion: @escaping (Card?) -> Void)
}

class GameScreenInteractor {
    weak var presenter: GameScreenInteractorOutputProtocol?
    
    // MARK: - Game Setup
    private func createInitialDeck(playerCount: Int) -> [Card] {
        var deck: [Card] = []
        
        for _ in 0..<5 {
            deck.append(Card(type: .nope))
        }
        
        for _ in 0..<4 {
            deck.append(Card(type: .attack))
        }
        
        for _ in 0..<4 {
            deck.append(Card(type: .skip))
        }
        
        for _ in 0..<4 {
            deck.append(Card(type: .favor))
        }
        
        for _ in 0..<4 {
            deck.append(Card(type: .shuffle))
        }
        
        for _ in 0..<5 {
            deck.append(Card(type: .seeTheFuture))
        }
        
        let catCards: [CardType] = [.catBeard, .catTaco, .catWatermelon, .catPotato]
        for catType in catCards {
            for _ in 0..<4 {
                deck.append(Card(type: catType))
            }
        }
        
        return deck.shuffled()
    }
    
    private func dealInitialCards(to players: [Player], from deck: inout [Card]) {
        for player in players {
            for _ in 0..<7 {
                if !deck.isEmpty {
                    let card = deck.removeFirst()
                    player.addCard(card)
                }
            }
            
            player.addCard(Card(type: .defuse))
        }
    }
    
    private func addDefuseCards(to deck: inout [Card], playerCount: Int) {
        let defuseCount = playerCount <= 3 ? 2 : (6 - playerCount)
        for _ in 0..<defuseCount {
            deck.append(Card(type: .defuse))
        }
    }
    
    private func addExplodingKittens(to deck: inout [Card], playerCount: Int) {
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
            presenter?.cardEffectApplied(message: "Nope! Action cancelled")
            
        default:
            break
        }
    }
    
    private func handleAttackCard(player: Player, gameState: GameState) {
        let leftoverTurns = max(0, player.turnsRemaining - 1)
        player.turnsRemaining = 0
        gameState.nextPlayer()
        if let nextPlayer = gameState.currentPlayer {
            nextPlayer.turnsRemaining = leftoverTurns + 2
            presenter?.cardEffectApplied(
                message: "\(nextPlayer.name) ходит \(nextPlayer.turnsRemaining) раз!")
        }
    }
    
    private func handleSkipCard(player: Player, gameState: GameState) {
        presenter?.cardEffectApplied(message: "\(player.name) skips their turn")
    }
    
    private func handleFavorCard(player: Player, gameState: GameState) {
        let otherPlayers = gameState.players.filter { $0.id != player.id && $0.isAlive && !$0.hand.isEmpty }

        guard !otherPlayers.isEmpty else {
            presenter?.cardEffectApplied(message: "No players to steal from")
            return
        }

        if player.type == .ai {
            guard let target = otherPlayers.max(by: { $0.hand.count < $1.hand.count }) else { return }
            executeFavorTransfer(from: target, to: player)
        } else {
            presenter?.promptPlayerSelection(availablePlayers: otherPlayers) { [weak self] target in
                self?.executeFavorTransfer(from: target, to: player)
            }
        }
    }


    private func executeFavorTransfer(from target: Player, to attacker: Player) {
        guard !target.hand.isEmpty else {
            presenter?.cardEffectApplied(message: "У \(target.name) нет карт")
            return
        }

        if target.type == .human {
            presenter?.promptCardFromHand(of: target, requesterName: attacker.name) { [weak self] picked in
                guard let self = self else { return }
                let card = picked ?? target.hand.first
                guard let chosen = card, let removed = target.removeCard(chosen) else { return }
                attacker.addCard(removed)
                self.presenter?.cardStolen(card: removed, from: target, to: attacker)
            }
        } else {
            guard let chosen = aiChoosesCardToGive(target: target),
                  let removed = target.removeCard(chosen) else { return }
            attacker.addCard(removed)
            presenter?.cardStolen(card: removed, from: target, to: attacker)
        }
    }


    private func aiChoosesCardToGive(target: Player) -> Card? {
        let priority: [CardType] = [
            .catBeard, .catTaco, .catWatermelon, .catPotato,
            .seeTheFuture, .shuffle,
            .skip, .favor, .attack,
            .nope,
            .defuse
        ]
        for type in priority {
            if let c = target.hand.first(where: { $0.type == type }) {
                return c
            }
        }
        return target.hand.first
    }
    
    private func handleShuffleCard(gameState: GameState) {
        gameState.deck.shuffle()
        presenter?.cardEffectApplied(message: "Deck shuffled")
    }
    
    private func handleSeeTheFutureCard(gameState: GameState) {
        let cardsToShow = Array(gameState.deck.prefix(3))
        presenter?.showSeeTheFutureCards(cardsToShow)
    }
    
    private func selectCardToStealByAI(from player: Player) -> Card? {
        let priority: [CardType] = [.defuse, .attack, .skip, .shuffle, .favor, .seeTheFuture, .nope]
        
        for cardType in priority {
            if let card = player.hand.first(where: { $0.type == cardType }) {
                return card
            }
        }
        
        return player.hand.first
    }
}

// MARK: - GameScreenInteractorProtocol
extension GameScreenInteractor: GameScreenInteractorProtocol {
    func setupGame(gameState: GameState) {

        let playerCount = gameState.gameMode.totalPlayers
        

        let humanPlayer = Player(name: "Player", type: .human)
        gameState.players.append(humanPlayer)
        
        if case .singlePlayer(let aiCount) = gameState.gameMode {
            for i in 1...aiCount {
                let aiPlayer = Player(name: "AI \(i)", type: .ai)
                gameState.players.append(aiPlayer)
            }
        }
        
        var deck = createInitialDeck(playerCount: playerCount)
        
        dealInitialCards(to: gameState.players, from: &deck)
        
  
        addDefuseCards(to: &deck, playerCount: playerCount)
        
     
        addExplodingKittens(to: &deck, playerCount: playerCount)
        

        deck.shuffle()
        gameState.deck = deck
        
        gameState.currentPlayerIndex = 0
    }
    
    func drawCard(for player: Player, gameState: GameState) {
        guard !gameState.deck.isEmpty else {
            presenter?.cardEffectApplied(message: "Deck is empty")
            return
        }
        
        let card = gameState.deck.removeFirst()
        
        if card.type == .explodingKitten {

            let hasDefuse = player.hasCard(ofType: .defuse)
            
            if hasDefuse {
       
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
