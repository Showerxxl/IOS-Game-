import Foundation
import AVFoundation

final class SoundManager {

    static let shared = SoundManager()


    private var backgroundPlayer: AVAudioPlayer?

    private var sfxPlayers: [String: [AVAudioPlayer]] = [:]

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup failed: \(error)")
        }
    }

    func startBackgroundMusic() {
        guard GameSettings.shared.musicEnabled else { return }
        if backgroundPlayer?.isPlaying == true { return }

        if backgroundPlayer == nil, let url = url(for: "background") {
            backgroundPlayer = try? AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1
            backgroundPlayer?.prepareToPlay()
        }
        backgroundPlayer?.volume = volumeForMusic
        backgroundPlayer?.play()
    }

    func stopBackgroundMusic() {
        backgroundPlayer?.stop()
    }

    func pauseBackgroundMusic() {
        backgroundPlayer?.pause()
    }


    func refreshSettings() {
        if GameSettings.shared.musicEnabled {
            startBackgroundMusic()
        } else {
            stopBackgroundMusic()
        }
        backgroundPlayer?.volume = volumeForMusic
    }

    func playTakeCard() { playSFX(named: "takecard") }


    func playMew()      { playSFX(named: "mew") }

    func playShuffle()  { playSFX(named: "shuffle") }


    func playAction()   { playSFX(named: "action") }

    func playSFX(named name: String) {
        guard GameSettings.shared.soundEffectsEnabled else { return }
        guard let url = url(for: name) else { return }

        var pool = sfxPlayers[name] ?? []
        pool.removeAll { !$0.isPlaying }

        let player: AVAudioPlayer
        if let free = pool.first(where: { !$0.isPlaying }) {
            player = free
        } else {
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.prepareToPlay()
            pool.append(p)
            player = p
        }
        player.volume = volumeForSFX
        player.currentTime = 0
        player.play()

        sfxPlayers[name] = pool
    }


    private func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp3")
    }

    private var volumeForMusic: Float {
        return GameSettings.shared.volume * 0.6
    }

    private var volumeForSFX: Float {
        return GameSettings.shared.volume
    }
}
