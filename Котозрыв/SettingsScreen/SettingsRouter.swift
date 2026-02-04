//
//  SettingsRouter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import UIKit

protocol SettingsRouterProtocol: AnyObject {
    static func createModule(fromScreen: SettingsSourceScreen) -> UIViewController
    func dismiss()
}

enum SettingsSourceScreen {
    case mainMenu
    case gameScreen
}

class SettingsRouter {
    weak var viewController: UIViewController?
    private var sourceScreen: SettingsSourceScreen
    
    init(sourceScreen: SettingsSourceScreen) {
        self.sourceScreen = sourceScreen
    }
    
    static func createModule(fromScreen: SettingsSourceScreen) -> UIViewController {
        let view = SettingsView()
        let presenter = SettingsPresenter()
        let interactor = SettingsInteractor()
        let router = SettingsRouter(sourceScreen: fromScreen)
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = view
        
        return view
    }
}

// MARK: - SettingsRouterProtocol
extension SettingsRouter: SettingsRouterProtocol {
    func dismiss() {
        viewController?.dismiss(animated: true)
    }
}
