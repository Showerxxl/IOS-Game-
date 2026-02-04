//
//  MainScreenInteractor.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol MainScreenInteractorProtocol: AnyObject {
    var presenter: MainScreenPresenterProtocol? { get set }
}

class MainScreenInteractor {
    weak var presenter: MainScreenPresenterProtocol?
}

// MARK: - MainScreenInteractorProtocol
extension MainScreenInteractor: MainScreenInteractorProtocol {
    
}
