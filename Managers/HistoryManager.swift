import Foundation

class HistoryManager {
    static let shared = HistoryManager()
    private let key = "LotteryHistory"
    
    // 保存一条新记录
    func save(result: LotteryResult) {
        var list = loadAll()
        // 新的最前面
        list.insert(result, at: 0)
        
        // 只保留最近 50 条，防止存太多
        if list.count > 50 {
            list = Array(list.prefix(50))
        }
        
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // 读取所有记录
    func loadAll() -> [LotteryResult] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([LotteryResult].self, from: data) else {
            return []
        }
        return list
    }
    
    // 清空
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
