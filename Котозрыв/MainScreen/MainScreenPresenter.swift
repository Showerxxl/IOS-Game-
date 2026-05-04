import Foundation

protocol MainScreenPresenterProtocol: AnyObject {
    var view: MainScreenViewProtocol? { get set }
    var interactor: MainScreenInteractorProtocol? { get set }
    var router: MainScreenRouterProtocol? { get set }
    
    func viewDidLoad()
    func singlePlayerButtonTapped()
    func multiplayerButtonTapped()
    func settingsButtonTapped()
}

class MainScreenPresenter {
    weak var view: MainScreenViewProtocol?
    var interactor: MainScreenInteractorProtocol?
    var router: MainScreenRouterProtocol?
}

extension MainScreenPresenter: MainScreenPresenterProtocol {
    func viewDidLoad() {
    }
    
    func singlePlayerButtonTapped() {
        router?.navigateToSinglePlayerGameSession()
    }
    
    func multiplayerButtonTapped() {
        router?.navigateToMultiplayerGame()
    }
    
    func settingsButtonTapped() {
        router?.navigateToSettings()
    }
}
