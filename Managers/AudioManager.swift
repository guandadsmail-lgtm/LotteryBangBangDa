import AVFoundation
import SwiftUI

class AudioManager {
    static let shared = AudioManager()
    
    private var players: [String: AVAudioPlayer] = [:]
    
    // 从 UserDefaults 读取开关 (默认开启)
    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "isSoundOn") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "isSoundOn")
    }
    
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func play(_ name: String, type: String = "mp3") {
        // 🔥 检查开关
        guard isEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[name] = player
        } catch {
            print("❌ 播放失败: \(error)")
        }
    }
    
    func playLoop(_ name: String, type: String = "mp3") {
        // 🔥 检查开关
        guard isEnabled else { return }
        
        if let player = players[name], player.isPlaying { return }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.6
            player.prepareToPlay()
            player.play()
            players[name] = player
        } catch {
            print("❌ 循环播放失败: \(error)")
        }
    }
    
    func stopLoop(_ name: String) {
        if let player = players[name] {
            player.stop()
            players.removeValue(forKey: name)
        }
    }
    
    func stopAll() {
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }
}
