import Foundation

struct LotteryResult: Identifiable, Codable {
    let id: UUID
    let date: Date
    let type: LotteryType // 确保这里引用的是 Models/LotteryType.swift 里的枚举
    let primaryBalls: [Int]
    let secondaryBalls: [Int]?
    
    var displayString: String {
        let p = primaryBalls.map { String(format: "%02d", $0) }.joined(separator: " ")
        if let s = secondaryBalls, !s.isEmpty {
            let b = s.map { String(format: "%02d", $0) }.joined(separator: " ")
            return "\(p) + \(b)"
        }
        return p
    }
}
