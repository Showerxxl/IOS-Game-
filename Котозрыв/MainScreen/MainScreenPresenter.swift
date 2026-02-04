//
//  MainScreenPresenter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol MainScreenPresenterProtocol: AnyObject {
    var view: MainScreenViewProtocol? { get set }
    var interactor: MainScreenInteractorProtocol? { get set }
    var router: MainScreenRouterProtocol? { get set }
    
    func viewDidLoad()
    func startButtonTapped()
    func settingsButtonTapped()
    func exitButtonTapped()
}

class MainScreenPresenter {
    weak var view: MainScreenViewProtocol?
    var interactor: MainScreenInteractorProtocol?
    var router: MainScreenRouterProtocol?
}

// MARK: - MainScreenPresenterProtocol
extension MainScreenPresenter: MainScreenPresenterProtocol {
    func viewDidLoad() {
        // Инициализация при загрузке
    }
    
    func startButtonTapped() {
        router?.navigateToGameSession()
    }
    
    func settingsButtonTapped() {
        router?.navigateToSettings()
    }
    
    func exitButtonTapped() {
        router?.exitApp()
    }
}
