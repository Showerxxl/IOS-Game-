//
//  GameScreenPresenter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol GameScreenPresenterProtocol: AnyObject {
    var view: GameScreenViewProtocol? { get set }
    var interactor: GameScreenInteractorProtocol? { get set }
    var router: GameScreenRouterProtocol? { get set }
    
    var players: [Player] { get }
    var currentPlayer: Player? { get }
    var currentPlayerHand: [Card] { get }
    var deckCount: Int { get }
    
    func viewDidLoad()
    func playCard(at index: Int)
    func drawCard()
    func endTurn()
    func settingsButtonTapped()
    func placeExplodingKitten(at position: Int)
}

class GameScreenPresenter {
    weak var view: GameScreenViewProtocol?
    var interactor: GameScreenInteractorProtocol?
    var router: GameScreenRouterProtocol?
    
    private var gameState: GameState
    
    init(gameState: GameState) {
        self.gameState = gameState
    }
    
    var players: [Player] {
        return gameState.players
    }
    
    var currentPlayer: Player? {
        return gameState.currentPlayer
    }
    
    var currentPlayerHand: [Card] {
        return gameState.currentPlayer?.hand ?? []
    }
    
    var deckCount: Int {
        return gameState.deck.count
    }
    
    private func processAITurn() {
        guard let aiPlayer = gameState.currentPlayer, aiPlayer.type == .ai else { return }
        
        view?.showMessage("\(aiPlayer.name) думает...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Простая логика ИИ
            let shouldPlayCard = Int.random(in: 0...10) > 6 && !aiPlayer.hand.isEmpty
            
            if shouldPlayCard, let randomCard = aiPlayer.hand.randomElement(),
               randomCard.type.isPlayable, randomCard.type != .defuse {
                
                if let index = aiPlayer.hand.firstIndex(where: { $0.id == randomCard.id }) {
                    self.handleCardPlay(card: randomCard, player: aiPlayer)
                    _ = aiPlayer.removeCard(randomCard)
                    self.view?.showCardEffect(randomCard.type)
                }
            }
            
            // ИИ берет карту
            self.performDrawCard()
        }
    }
    
    private func handleCardPlay(card: Card, player: Player) {
        interactor?.playCard(card: card, by: player, gameState: gameState)
    }
    
    private func performDrawCard() {
        guard let player = gameState.currentPlayer else { return }
        
        interactor?.drawCard(for: player, gameState: gameState)
    }
    
    private func checkGameOver() {
        let alivePlayers = gameState.alivePlayers()
        if alivePlayers.count == 1 {
            gameState.isGameOver = true
            gameState.winner = alivePlayers.first
            if let winner = gameState.winner {
                view?.navigateToGameOver(winner: winner)
            }
        }
    }
}

// MARK: - GameScreenPresenterProtocol
extension GameScreenPresenter: GameScreenPresenterProtocol {
    func viewDidLoad() {
        interactor?.setupGame(gameState: gameState)
        view?.updateUI()
        
        // Если первый игрок - ИИ, начинаем его ход
        if gameState.currentPlayer?.type == .ai {
            processAITurn()
        }
    }
    
    func playCard(at index: Int) {
        guard let player = gameState.currentPlayer,
              player.type == .human,
              index < player.hand.count else { return }
        
        let card = player.hand[index]
        
        guard card.type.isPlayable else {
            view?.showMessage("Эту карту нельзя сыграть")
            return
        }
        
        handleCardPlay(card: card, player: player)
        _ = player.removeCard(card)
        gameState.discardPile.append(card)
        view?.showCardEffect(card.type)
        view?.updateUI()
    }
    
    func drawCard() {
        guard let player = gameState.currentPlayer,
              player.type == .human else { return }
        
        performDrawCard()
    }
    
    func endTurn() {
        guard let player = gameState.currentPlayer else { return }
        
        if player.turnsRemaining > 0 {
            player.turnsRemaining -= 1
        }
        
        if player.turnsRemaining == 0 {
            player.turnsRemaining = 1
            gameState.nextPlayer()
            view?.updateUI()
            
            if gameState.currentPlayer?.type == .ai {
                processAITurn()
            }
        }
    }
    
    func settingsButtonTapped() {
        router?.navigateToSettings()
    }
    
    func placeExplodingKitten(at position: Int) {
        interactor?.placeExplodingKittenInDeck(at: position, gameState: gameState)
        endTurn()
    }
}

// MARK: - GameScreenInteractorOutputProtocol
extension GameScreenPresenter: GameScreenInteractorOutputProtocol {
    func cardDrawn(card: Card, by player: Player) {
        view?.showMessage("\(player.name) взял карту: \(card.type.rawValue)")
        view?.updateUI()
        
        if card.type != .explodingKitten {
            // Автоматически завершаем ход после взятия карты (если не взрывной котенок)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.endTurn()
            }
        }
    }
    
    func playerExploded(_ player: Player, hasDefuse: Bool) {
        if hasDefuse {
            view?.showMessage("\(player.name) взял Взрывного котёнка! Используйте Обезвредь")
            view?.showDefuseOptions()
        } else {
            view?.showMessage("\(player.name) взорвался!")
            player.isAlive = false
            checkGameOver()
            
            if !gameState.isGameOver {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.endTurn()
                }
            }
        }
    }
    
    func showSeeTheFutureCards(_ cards: [Card]) {
        view?.showSeeTheFutureCards(cards)
    }
    
    func promptPlayerSelection(availablePlayers: [Player], completion: @escaping (Player) -> Void) {
        view?.promptSelectPlayer(players: availablePlayers, completion: completion)
    }
    
    func promptCardSelection(from player: Player, completion: @escaping (CardType?) -> Void) {
        view?.promptSelectCard(from: player, completion: completion)
    }
    
    func cardEffectApplied(message: String) {
        view?.showMessage(message)
        view?.updateUI()
    }
}
