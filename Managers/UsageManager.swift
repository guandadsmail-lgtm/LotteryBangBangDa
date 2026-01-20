import SwiftUI
import Combine

class UsageManager: ObservableObject {
    static let shared = UsageManager()
    
    // VIP 状态
    @Published var isVip: Bool {
        didSet { UserDefaults.standard.set(isVip, forKey: "isVipUser") }
    }
    
    // 已使用次数
    @Published var usageCount: Int {
        didSet { UserDefaults.standard.set(usageCount, forKey: "trialUsageCount") }
    }
    
    // 最大免费次数
    let maxTrialCount = 10
    
    private init() {
        self.isVip = UserDefaults.standard.bool(forKey: "isPro") // 统一用 isPro
        self.usageCount = UserDefaults.standard.integer(forKey: "trialUsageCount")
    }
    
    // 供外部更新 VIP 状态
    func setVipStatus(_ status: Bool) {
        if self.isVip != status {
            DispatchQueue.main.async { self.isVip = status }
        }
    }
    
    // 判断是否能玩
    var canPlay: Bool {
        if isVip { return true }
        return usageCount < maxTrialCount
    }
    
    // 增加计数
    func incrementUsage() {
        if !isVip {
            DispatchQueue.main.async { self.usageCount += 1 }
        }
    }
    
    // 🔥 修复点：这里改成了属性 (var)，解决 RootView 的 "no dynamic member" 报错
    var remainingText: String {
        if isVip { return "" }
        let left = max(0, maxTrialCount - usageCount)
        return String(localized: "剩余试用: \(left) 次")
    }
    
    // 兼容旧代码的方法（如果其他地方用了）
    func getTrialStatusText() -> String {
        return remainingText
    }
}
