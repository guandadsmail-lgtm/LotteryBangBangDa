import Foundation

// 加上 Codable 协议，才能存入硬盘
struct LotteryBall: Identifiable, Hashable, Codable {
    var id = UUID()
    let number: Int
    let color: String // "red", "blue"
}

struct LotteryResult: Identifiable, Codable {
    var id = UUID()
    let type: LotteryType
    let date: Date
    let primaryBalls: [LotteryBall]    // 红球
    let secondaryBalls: [LotteryBall]? // 蓝球
    
    // 方便显示的格式化字符串
    var displayString: String {
        let p = primaryBalls.map { String(format: "%02d", $0.number) }.joined(separator: " ")
        if let s = secondaryBalls, !s.isEmpty {
            let b = s.map { String(format: "%02d", $0.number) }.joined(separator: " ")
            return "\(p) + \(b)"
        }
        return p
    }
}
