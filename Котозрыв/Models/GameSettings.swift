//
//  GameSettings.swift
//  Котозрыв
//
//  Created by Mac on 04.02.2026.
//

import Foundation

class GameSettings {
    static let shared = GameSettings()
    
    private let soundEffectsKey = "soundEffectsEnabled"
    private let musicKey = "musicEnabled"
    private let volumeKey = "volume"
    
    private init() {}
    
    var soundEffectsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: soundEffectsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: soundEffectsKey)
        }
    }
    
    var musicEnabled: Bool {
        get {
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
