import SwiftUI

// MARK: - 游戏配置参数
struct GameEngineConfig {
    static let ballRadius: CGFloat = 15.0
    static let categoryBall: UInt32 = 0x1 << 0
    static let categoryWall: UInt32 = 0x1 << 1
    static let categoryFloor: UInt32 = 0x1 << 2
    static let redBallColor = "FF3B30"
    static let blueBallColor = "007AFF"
    
    struct Timing {
        static let turbulenceDuration: TimeInterval = 7.0
    }
}

// MARK: - 彩种定义
enum LotteryType: String, CaseIterable, Identifiable, Codable {
    case ssq = "双色球"
    case dlt = "大乐透"
    case fc3d = "福彩3D"
    case pl3 = "排列三"
    case pl5 = "排列五"
    
    var id: String { rawValue }
    
    var style: MachineStyle {
        switch self {
        case .ssq, .dlt: return .bigMixer
        case .fc3d, .pl3, .pl5: return .slotMachine
        }
    }
    
    var slotColumns: Int {
        switch self {
        case .fc3d, .pl3: return 3
        case .pl5: return 5
        default: return 0
        }
    }
    
    var redConfig: (range: Range<Int>, count: Int) {
        switch self {
        case .ssq: return (1..<34, 6)
        case .dlt: return (1..<36, 5)
        case .fc3d, .pl3: return (0..<10, 3)
        case .pl5: return (0..<10, 5)
        }
    }
    
    var blueConfig: (range: Range<Int>, count: Int) {
        switch self {
        case .ssq: return (1..<17, 1)
        case .dlt: return (1..<13, 2)
        default: return (0..<0, 0)
        }
    }
    
    var config: [BallConfig] {
        return [
            BallConfig(color: .red, range: redConfig.range),
            BallConfig(color: .blue, range: blueConfig.range)
        ]
    }
}

struct BallConfig {
    let color: BallColor
    let range: Range<Int>
}
enum BallColor { case red, blue }

enum MachineStyle {
    case bigMixer     // 物理搅拌
    case slotMachine  // 滚轮老虎机
}

// MARK: - 通知信号
import Foundation
extension Notification.Name {
    static let startRedPhase = Notification.Name("StartRedPhase")
    static let redPhaseFinished = Notification.Name("RedPhaseFinished")
    static let startBluePhase = Notification.Name("StartBluePhase")
    static let allFinished = Notification.Name("AllFinished")
    static let resetScene = Notification.Name("ResetScene")
    
    // 老虎机专用
    static let startSlotMachine = Notification.Name("StartSlotMachine") // 开始转
    static let stopSlotMachine = Notification.Name("StopSlotMachine")   // 停止转
}
