//
//  GameSessionInteractor.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol GameSessionInteractorProtocol: AnyObject {
    var presenter: GameSessionInteractorOutputProtocol? { get set }
    func prepareGame(with mode: GameMode)
}

protocol GameSessionInteractorOutputProtocol: AnyObject {
    func gameReadyToStart(with gameState: GameState)
}

class GameSessionInteractor {
    weak var presenter: GameSessionInteractorOutputProtocol?
}

// MARK: - GameSessionInteractorProtocol
extension GameSessionInteractor: GameSessionInteractorProtocol {
    func prepareGame(with mode: GameMode) {
        let gameState = GameState(gameMode: mode)
        presenter?.gameReadyToStart(with: gameState)
    }
}
