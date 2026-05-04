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
        SoundManager.shared.refreshSettings()
    }

    func saveMusic(enabled: Bool) {
        settings.musicEnabled = enabled
        SoundManager.shared.refreshSettings()
    }

    func saveVolume(_ value: Float) {
        settings.volume = value
        SoundManager.shared.refreshSettings()
    }
}
