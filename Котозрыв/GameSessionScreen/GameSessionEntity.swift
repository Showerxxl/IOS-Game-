import Foundation

struct GameSessionConfiguration {
    let gameMode: GameMode
    let totalPlayers: Int
    
    init(gameMode: GameMode) {
        self.gameMode = gameMode
        self.totalPlayers = gameMode.totalPlayers
    }
}
