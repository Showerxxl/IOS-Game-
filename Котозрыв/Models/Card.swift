//
//  Card.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

struct Card: Equatable, Identifiable {
    let id: UUID
    let type: CardType
    
    init(type: CardType) {
        self.id = UUID()
        self.type = type
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id
    }
}
