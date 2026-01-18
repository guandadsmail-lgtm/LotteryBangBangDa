import UIKit
import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    
    // 从 UserDefaults 读取开关设置 (默认开启)
    var isEnabled: Bool {
        // 如果没有设置过，默认为 true
        if UserDefaults.standard.object(forKey: "isHapticOn") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "isHapticOn")
    }
    
    private init() {}
    
    // 重击 (开始/摇一摇)
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // 通知 (成功/复制)
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
