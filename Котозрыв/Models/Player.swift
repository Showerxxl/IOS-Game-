//
//  Player.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

enum PlayerType {
    case human
    case ai
}

class Player {
    let id: UUID
    let name: String
    let type: PlayerType
    var hand: [Card]
    var isAlive: Bool
    var turnsRemaining: Int
    
    init(name: String, type: PlayerType) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.hand = []
        self.isAlive = true
        self.turnsRemaining = 1
    }
    
    func addCard(_ card: Card) {
        hand.append(card)
    }
    
    func removeCard(_ card: Card) -> Card? {
        if let index = hand.firstIndex(where: { $0.id == card.id }) {
            return hand.remove(at: index)
        }
        return nil
    }
    
    func hasCard(ofType type: CardType) -> Bool {
        return hand.contains(where: { $0.type == type })
    }
    
    func getCards(ofType type: CardType) -> [Card] {
        return hand.filter { $0.type == type }
    }
}
