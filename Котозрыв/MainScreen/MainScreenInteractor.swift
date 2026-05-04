import Foundation

protocol MainScreenInteractorProtocol: AnyObject {
    var presenter: MainScreenPresenterProtocol? { get set }
}

class MainScreenInteractor {
    weak var presenter: MainScreenPresenterProtocol?
}

extension MainScreenInteractor: MainScreenInteractorProtocol {
    
}
