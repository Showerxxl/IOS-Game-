//
//  GameState.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

class GameState {
    var players: [Player]
    var deck: [Card]
    var discardPile: [Card]
    var currentPlayerIndex: Int
    var gameMode: GameMode
    var isGameOver: Bool
    var winner: Player?
    
    init(gameMode: GameMode) {
        self.players = []
        self.deck = []
        self.discardPile = []
        self.currentPlayerIndex = 0
        self.gameMode = gameMode
        self.isGameOver = false
        self.winner = nil
    }
    
    var currentPlayer: Player? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }
    
    func nextPlayer() {
        repeat {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        } while !players[currentPlayerIndex].isAlive && players.filter({ $0.isAlive }).count > 1
    }
    
    func alivePlayers() -> [Player] {
        return players.filter { $0.isAlive }
    }
}

enum GameMode {
    case singlePlayer(aiCount: Int)
    
    var totalPlayers: Int {
        switch self {
        case .singlePlayer(let aiCount):
            return aiCount + 1
        }
    }
}
