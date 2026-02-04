//
//  SettingsPresenter.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol SettingsPresenterProtocol: AnyObject {
    var view: SettingsViewProtocol? { get set }
    var interactor: SettingsInteractorProtocol? { get set }
    var router: SettingsRouterProtocol? { get set }
    
    func viewDidLoad()
    func soundEffectsToggled(_ enabled: Bool)
    func musicToggled(_ enabled: Bool)
    func volumeChanged(_ value: Float)
    func closeButtonTapped()
}

class SettingsPresenter {
    weak var view: SettingsViewProtocol?
    var interactor: SettingsInteractorProtocol?
    var router: SettingsRouterProtocol?
}

// MARK: - SettingsPresenterProtocol
extension SettingsPresenter: SettingsPresenterProtocol {
    func viewDidLoad() {
        let settings = interactor?.loadSettings()
        view?.updateSoundEffects(enabled: settings?.soundEffectsEnabled ?? false)
        view?.updateMusic(enabled: settings?.musicEnabled ?? false)
        view?.updateVolume(settings?.volume ?? 0.5)
    }
    
    func soundEffectsToggled(_ enabled: Bool) {
        interactor?.saveSoundEffects(enabled: enabled)
    }
    
    func musicToggled(_ enabled: Bool) {
        interactor?.saveMusic(enabled: enabled)
    }
    
    func volumeChanged(_ value: Float) {
        interactor?.saveVolume(value)
    }
    
    func closeButtonTapped() {
        router?.dismiss()
    }
}
