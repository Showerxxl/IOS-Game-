//
//  GameSessionEntity.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

struct GameSessionConfiguration {
    let gameMode: GameMode
    let totalPlayers: Int
    
    init(gameMode: GameMode) {
        self.gameMode = gameMode
        self.totalPlayers = gameMode.totalPlayers
    }
}
