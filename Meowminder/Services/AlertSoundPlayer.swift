import AVFoundation

/// Loops the alert sound for as long as an overlay is on screen, and stops
/// the instant the user taps Accept or Snooze. One shared player, since only
/// one overlay is ever presented at a time (the FIFO queue guarantees that).
final class AlertSoundPlayer {
    static let shared = AlertSoundPlayer()
    private var player: AVAudioPlayer?

    private init() {}

    func startLooping(resource: String = "AlertSound", ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            print("AlertSoundPlayer: couldn't find \(resource).\(ext) in the app bundle")
            return
        }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1 // repeat indefinitely until stop() is called
            newPlayer.volume = 1.0
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            print("AlertSoundPlayer: failed to start playback — \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
