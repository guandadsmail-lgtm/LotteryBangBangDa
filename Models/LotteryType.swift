import Foundation

enum LotteryType: String, CaseIterable, Identifiable, Codable {
    case doubleColor = "双色球"
    case superLotto = "大乐透"
    case arrangement3 = "排列三"
    case arrangement5 = "排列五"
    case threeD = "3D"
    
    var id: String { self.rawValue }
    
    // 显示名称 (支持国际化)
    var displayName: String {
        switch self {
        case .doubleColor: return String(localized: "双色球")
        case .superLotto: return String(localized: "大乐透")
        case .arrangement3: return String(localized: "排列三")
        case .arrangement5: return String(localized: "排列五")
        case .threeD: return String(localized: "福彩3D")
        }
    }
    
    // 老虎机列数 = 红球数 + 蓝球数
    var slotColumns: Int {
        return redConfig.count + blueConfig.count
    }
    
    // 样式配置
    var style: GameStyle {
        switch self {
        case .doubleColor, .superLotto:
            return .bigMixer // 搅拌机模式
        case .arrangement3, .arrangement5, .threeD:
            return .slotMachine // 老虎机模式
        }
    }
    
    // 红球配置 (范围, 数量)
    var redConfig: (range: ClosedRange<Int>, count: Int) {
        switch self {
        case .doubleColor: return (1...33, 6)
        case .superLotto: return (1...35, 5)
        case .arrangement3: return (0...9, 3)  // 排列3：3个数字
        case .arrangement5: return (0...9, 5)  // 排列5：5个数字
        case .threeD: return (0...9, 3)        // 3D：3个数字
        }
    }
    
    // 蓝球配置
    var blueConfig: (range: ClosedRange<Int>, count: Int) {
        switch self {
        case .doubleColor: return (1...16, 1)
        case .superLotto: return (1...12, 2)
        default: return (0...0, 0) // 排列3/5、3D 没有蓝球
        }
    }
}

enum GameStyle: String, Codable {
    case bigMixer
    case slotMachine
}
