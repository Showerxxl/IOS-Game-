//
//  GameScreenRouter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol GameScreenRouterProtocol: AnyObject {
    static func createModule(with gameState: GameState) -> UIViewController
    func navigateToSettings()
    func navigateToMainMenu()
}

class GameScreenRouter {
    weak var viewController: UIViewController?
    
    static func createModule(with gameState: GameState) -> UIViewController {
        let view = GameScreenView()
        let presenter = GameScreenPresenter(gameState: gameState)
        let interactor = GameScreenInteractor()
        let router = GameScreenRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
}

// MARK: - GameScreenRouterProtocol
extension GameScreenRouter: GameScreenRouterProtocol {
    func navigateToSettings() {
        let settingsVC = SettingsRouter.createModule(fromScreen: .gameScreen)
        viewController?.present(settingsVC, animated: true)
    }
    
    func navigateToMainMenu() {
        viewController?.navigationController?.popToRootViewController(animated: true)
    }
}
