import SwiftUI
import Combine

class UsageManager: ObservableObject {
    static let shared = UsageManager()
    
    // MARK: - 持久化属性
    
    // 1. VIP 状态
    @Published var isVip: Bool {
        didSet {
            UserDefaults.standard.set(isVip, forKey: "isVipUser")
        }
    }
    
    // 2. 已使用次数
    @Published var usageCount: Int {
        didSet {
            UserDefaults.standard.set(usageCount, forKey: "trialUsageCount")
        }
    }
    
    // 最大免费次数
    let maxTrialCount = 10
    
    // 初始化时从 UserDefaults 读取
    private init() {
        self.isVip = UserDefaults.standard.bool(forKey: "isVipUser")
        self.usageCount = UserDefaults.standard.integer(forKey: "trialUsageCount")
    }
    
    // MARK: - 逻辑方法
    
    // 提供给 StoreManager 更新状态用
    func setVipStatus(_ status: Bool) {
        // 只有状态真的改变了才更新，避免死循环
        if self.isVip != status {
            DispatchQueue.main.async {
                self.isVip = status
            }
        }
    }
    
    // 核心判断：能不能玩？
    var canPlay: Bool {
        if isVip { return true } // 是 VIP，无限玩
        return usageCount < maxTrialCount // 不是 VIP，看次数
    }
    
    // 增加一次计数
    func incrementUsage() {
        if !isVip {
            usageCount += 1
        }
    }
    
    // 获取剩余次数文案
    var remainingText: String {
        if isVip { return "PRO 版无限畅玩" }
        let left = max(0, maxTrialCount - usageCount)
        return "免费试用剩余: \(left) 次"
    }
    
    // 重置试用（仅用于测试或特殊奖励）
    func resetTrial() {
        usageCount = 0
    }
}
