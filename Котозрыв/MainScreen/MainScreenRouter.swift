import UIKit

protocol MainScreenRouterProtocol: AnyObject {
    static func createModule() -> UIViewController
    func navigateToSinglePlayerGameSession()
    func navigateToMultiplayerGame()
    func navigateToSettings()
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
    func navigateToSinglePlayerGameSession() {
        let gameSessionVC = GameSessionRouter.createModule()
        viewController?.navigationController?.pushViewController(gameSessionVC, animated: true)
    }
    
    func navigateToMultiplayerGame() {
        let multiplayerVC = MultiplayerLobbyView()
        viewController?.navigationController?.pushViewController(multiplayerVC, animated: true)
    }
    
    func navigateToSettings() {
        let settingsVC = SettingsRouter.createModule(fromScreen: .mainMenu)
        viewController?.present(settingsVC, animated: true)
    }
}
