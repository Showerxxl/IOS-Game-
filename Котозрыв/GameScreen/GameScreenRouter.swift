import UIKit

protocol GameScreenRouterProtocol: AnyObject {
    static func createModule(with gameState: GameState) -> UIViewController
    func navigateToSettings()
    func navigateToMainMenu()
}

class GameScreenRouter {
    weak var viewController: UIViewController?

    static func createMultiplayerModule(myPlayerId: String, roomId: String) -> UIViewController {
        let view      = GameScreenView()
        let presenter = MultiplayerGamePresenter(myPlayerId: myPlayerId, roomId: roomId)
        let router    = GameScreenRouter()

        view.presenter      = presenter
        presenter.view      = view
        presenter.router    = router
        router.viewController = view

        return view
    }

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
