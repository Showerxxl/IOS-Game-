//
//  GameSessionPresenter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol GameSessionPresenterProtocol: AnyObject {
    var view: GameSessionViewProtocol? { get set }
    var interactor: GameSessionInteractorProtocol? { get set }
    var router: GameSessionRouterProtocol? { get set }
    
    func viewDidLoad()
    func aiCountChanged(_ count: Int)
    func startGameTapped(aiCount: Int)
    func backButtonTapped()
}

class GameSessionPresenter {
    weak var view: GameSessionViewProtocol?
    var interactor: GameSessionInteractorProtocol?
    var router: GameSessionRouterProtocol?
    
    private var currentAICount: Int = 1
}

// MARK: - GameSessionPresenterProtocol
extension GameSessionPresenter: GameSessionPresenterProtocol {
    func viewDidLoad() {
        view?.updateAIPlayersCount(currentAICount)
    }
    
    func aiCountChanged(_ count: Int) {
        currentAICount = count
    }
    
    func startGameTapped(aiCount: Int) {
        let gameMode = GameMode.singlePlayer(aiCount: aiCount)
        interactor?.prepareGame(with: gameMode)
    }
    
    func backButtonTapped() {
        router?.navigateBack()
    }
}

// MARK: - GameSessionInteractorOutputProtocol
extension GameSessionPresenter: GameSessionInteractorOutputProtocol {
    func gameReadyToStart(with gameState: GameState) {
        router?.navigateToGameScreen(with: gameState)
    }
}
