import Foundation

class GameSettings {
    static let shared = GameSettings()
    
    private let soundEffectsKey = "soundEffectsEnabled"
    private let musicKey = "musicEnabled"
    private let volumeKey = "volume"
    
    private init() {}
    
    var soundEffectsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: soundEffectsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: soundEffectsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: soundEffectsKey)
        }
    }

    var musicEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: musicKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: musicKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: musicKey)
        }
    }
    
    var volume: Float {
        get {
            let value = UserDefaults.standard.float(forKey: volumeKey)
            return value == 0 ? 0.5 : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: volumeKey)
        }
    }
}
