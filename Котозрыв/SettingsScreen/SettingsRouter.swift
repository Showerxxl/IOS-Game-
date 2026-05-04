import UIKit

protocol SettingsRouterProtocol: AnyObject {
    static func createModule(fromScreen: SettingsSourceScreen) -> UIViewController
    func dismiss()
    func navigateToRules()
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

extension SettingsRouter: SettingsRouterProtocol {
    func dismiss() {
        viewController?.dismiss(animated: true)
    }

    func navigateToRules() {
        let rules = RulesView()
        rules.modalPresentationStyle = .fullScreen
        viewController?.present(rules, animated: true)
    }
}
