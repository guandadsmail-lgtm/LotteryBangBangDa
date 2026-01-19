import SwiftUI

// 必须确保项目中只有这一处 enum LotteryType 定义
enum LotteryType: String, CaseIterable, Identifiable, Codable {
    case doubleColor = "双色球"
    case superLotto = "大乐透"
    case arr3 = "排列三"
    case arr5 = "排列五"
    case fc3d = "福彩3D"
    
    var id: String { self.rawValue }
    
    // 样式区分
    var style: LotteryStyle {
        switch self {
        case .doubleColor, .superLotto:
            return .bigMixer // 搅拌机
        default:
            return .slotMachine // 老虎机
        }
    }
    
    // 老虎机列数
    var slotColumns: Int {
        switch self {
        case .arr5: return 5
        default: return 3
        }
    }
    
    // 选球配置 (红球)
    var redConfig: (count: Int, range: Range<Int>) {
        switch self {
        case .doubleColor: return (6, 1..<34)
        case .superLotto: return (5, 1..<36)
        default: return (0, 0..<0)
        }
    }
    
    // 选球配置 (蓝球)
    var blueConfig: (count: Int, range: Range<Int>) {
        switch self {
        case .doubleColor: return (1, 1..<17)
        case .superLotto: return (2, 1..<13)
        default: return (0, 0..<0)
        }
    }
}

enum LotteryStyle: Codable {
    case bigMixer
    case slotMachine
}
