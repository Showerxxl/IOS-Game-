//
//  GameSessionRouter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol GameSessionRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToGameScreen(with gameState: GameState)
    func navigateBack()
}

class GameSessionRouter {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let view = GameSessionView()
        let presenter = GameSessionPresenter()
        let interactor = GameSessionInteractor()
        let router = GameSessionRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
}

// MARK: - GameSessionRouterProtocol
extension GameSessionRouter: GameSessionRouterProtocol {
    func navigateToGameScreen(with gameState: GameState) {
        let gameVC = GameScreenRouter.createModule(with: gameState)
        viewController?.navigationController?.pushViewController(gameVC, animated: true)
    }
    
    func navigateBack() {
        viewController?.navigationController?.popViewController(animated: true)
    }
}
