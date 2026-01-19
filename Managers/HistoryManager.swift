import Foundation

// ⚠️ 注意：这里删除了 struct LotteryResult，因为它在 Models/LotteryResult.swift 里定义了

class HistoryManager {
    static let shared = HistoryManager()
    private let key = "lottery_history_v1"
    
    private init() {}
    
    // 保存记录
    func add(type: LotteryType, reds: [Int], blues: [Int] = []) {
        let newRecord = LotteryResult(
            id: UUID(),
            date: Date(),
            type: type,
            primaryBalls: reds,
            secondaryBalls: blues.isEmpty ? nil : blues
        )
        
        var history = loadAll()
        history.insert(newRecord, at: 0) // 插到最前面
        
        // 限制只存最近 100 条
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        save(history)
    }
    
    // 读取所有
    func loadAll() -> [LotteryResult] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        if let decoded = try? JSONDecoder().decode([LotteryResult].self, from: data) {
            return decoded
        }
        return []
    }
    
    // 清空
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    private func save(_ records: [LotteryResult]) {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
