//
//  MainScreenRouter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol MainScreenRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToGameSession()
    func navigateToSettings()
    func exitApp()
}

class MainScreenRouter {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let view = MainScreenView()
        let presenter = MainScreenPresenter()
        let interactor = MainScreenInteractor()
        let router = MainScreenRouter()
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
}

// MARK: - MainScreenRouterProtocol
extension MainScreenRouter: MainScreenRouterProtocol {
    func navigateToGameSession() {
        let gameSessionVC = GameSessionRouter.createModule()
        viewController?.navigationController?.pushViewController(gameSessionVC, animated: true)
    }
    
    func navigateToSettings() {
        let settingsVC = SettingsRouter.createModule(fromScreen: .mainMenu)
        viewController?.present(settingsVC, animated: true)
    }
    
    func exitApp() {
        exit(0)
    }
}
