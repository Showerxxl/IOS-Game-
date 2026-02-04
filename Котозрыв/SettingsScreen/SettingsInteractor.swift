//
//  SettingsInteractor.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

protocol SettingsInteractorProtocol: AnyObject {
    var presenter: SettingsPresenterProtocol? { get set }
    func loadSettings() -> (soundEffectsEnabled: Bool, musicEnabled: Bool, volume: Float)
    func saveSoundEffects(enabled: Bool)
    func saveMusic(enabled: Bool)
    func saveVolume(_ value: Float)
}

class SettingsInteractor {
    weak var presenter: SettingsPresenterProtocol?
    private let settings = GameSettings.shared
}

// MARK: - SettingsInteractorProtocol
extension SettingsInteractor: SettingsInteractorProtocol {
    func loadSettings() -> (soundEffectsEnabled: Bool, musicEnabled: Bool, volume: Float) {
        return (
            soundEffectsEnabled: settings.soundEffectsEnabled,
            musicEnabled: settings.musicEnabled,
            volume: settings.volume
        )
    }
    
    func saveSoundEffects(enabled: Bool) {
        settings.soundEffectsEnabled = enabled
    }
    
    func saveMusic(enabled: Bool) {
        settings.musicEnabled = enabled
    }
    
    func saveVolume(_ value: Float) {
        settings.volume = value
    }
}
